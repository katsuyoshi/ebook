require 'sinatra'
require 'sinatra/reloader'
require 'logger'
require 'base64'
require 'openssl'

require 'dotenv'
Dotenv.load
require './lineworks'

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
  file_id = get_file_id params
  res = LineWorks.instance.download_file file_id
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
