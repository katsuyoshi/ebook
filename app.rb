require 'sinatra'
require 'sinatra/reloader'
require 'logger'
require 'base64'
require 'openssl'

require 'dotenv'
Dotenv.load
require './lineworks'
require './hexabase'
require './s3'


logger = Logger.new('sinatra.log')

token = LineWorks.instance.access_token

def check_signature body, signature
  digest = Base64.strict_encode64(OpenSSL::HMAC.digest('SHA256', ENV['LINEWORKS_BOT_SECRET'], body))
  digest == signature
end

def get_message params
  case params["type"]
  when "message"
    params["content"]["text"]
  else
    nil
  end
end

def get_user_id params
  params["source"]["userId"]
end

def get_file_id params
  params["content"]["fileId"]
end


def echo_message params
  user_id = get_user_id params
  message = get_message params
  res = LineWorks.instance.send_message user_id, message
  logger.info res
end

def download_file params
  user_id = get_user_id params
  lw = LineWorks.instance

  # download file from Lineworkks
  file_id = get_file_id params
  file_info = LineWorks.instance.download_file file_id
  lw.send_message user_id, 'ファイルを読み込みました。'

  # create new record
  hb = Hexabase.instance
  item = hb.create
  logger.info item
  lw.send_message user_id, 'レコードを作りました。'

  # store file to S3 bucket
  s3 = S3.instance
  path = s3.upload(file_info[:file_data], File.join(item['record_no'], file_info[:file_name]))
  logger.info path
  lw.send_message user_id, 'ファイルをS3に登録しました。'

  # update record
  item["file_url"] = path
  item["file_name"] = file_info[:file_name]
  hb.update item
  lw.send_message user_id, 'レコードを更新しました。'

end

def dispatch params
  case params["type"]
  when "message"
    case params["content"]["type"]
    when "text"
      echo_message params
    when "file"
      download_file params
    end
  end
end



get '/' do
  'Hello world!'
end

post '/lineworks/callback' do
  headers = request.env.select { |k, v| k.start_with?('HTTP_') }
  body = request.body.read
  return 400 unless check_signature body, headers['HTTP_X_WORKS_SIGNATURE']

  params = JSON.parse body
  logger.info headers
  logger.info params

  dispatch params

  'OK'
end
