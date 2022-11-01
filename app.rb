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
require './google_vision'

#enable :sessions


logger = Logger.new('sinatra.log')

token = LineWorks.instance.access_token


REGIST_STATE_IDLE             = 0
REGIST_STATE_REQUEST_IMAGE    = 1
REGIST_STATE_UPLOADING        = 2
REGIST_STATE_SHOW_SUMMARY     = 3
REGIST_STATE_SHOW_SUMMARY_RES = 4
REGIST_STATE_QUERY_DEAL_AT    = 5
REGIST_STATE_QUERY_COMPANY    = 6
REGIST_STATE_QUERY_AMOUNT     = 7

$session = {}

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


def send_message message, params 
  user_id = get_user_id params
  res = LineWorks.instance.send_message user_id, message
  logger.info res
end

def echo_message params
  message = get_message params
  send_message message, params
end

def regist_file params
  logger.info "registing file"
  #return unless $session[:state] == REGIST_STATE_REQUEST_IMAGE

  user_id = get_user_id params
  lw = LineWorks.instance

  # download file from Lineworkks
  logger.info "downloading file from Lineworks"
  file_id = get_file_id params
  file_info = LineWorks.instance.download_file file_id
p file_info[:file_name]
  unless %w(png jpg jpeg pdf).include?(File.extname(file_info[:file_name])[1..-1])
    send_message '画像またはPDFファイルをアップロードしてください。', params
    return
  end
  logger.info "downloaded file from Lineworks"

  # create new record
  logger.info "creating a record"
  hb = Hexabase.instance
  item = hb.create
  logger.info item
  logger.info "created a record"
  lw.send_message user_id, 'レコードを作りました。'
  $session[:item] = item
  logger.info item

  # store file to S3 bucket
  logger.info "storing a file"
  logger.info item['record_no']
  logger.info file_info[:file_name]
  s3 = S3.instance
  path = s3.upload(file_info[:file_data], File.join(item['record_no'], file_info[:file_name]))
  logger.info path
  logger.info "stored a file"
  lw.send_message user_id, 'ファイルを登録しました。'

  # update record
  item["file_url"] = path
  item["file_name"] = file_info[:file_name]

  # processing image
  logger.info "getting slip"
  gv = GoogleVision.instance
  slip = gv.ocr file_info[:file_data]
p slip
  $session[:slip] = slip
  lw.send_message user_id, '画像を読み取りました。'
  logger.info "got slip"
  logger.info slip

  $session[:state] = REGIST_STATE_SHOW_SUMMARY
  handle_state params
end

def send_query_buttons message, candidates, params
  LineWorks.instance.query_buttons get_user_id(params), message, candidates
end

def reset
  $session = []
end

def regist_slip
  hb = Hexabase.instance
  # update record
  logger.info "updating the record"
  slip = $session[:slip]
  item = $session[:item]
  item['deal_kind'] = slip.deal_kind
  item['deal_at'] = slip.deal_at
  item['customer'] = slip.customer
  item['total'] = slip.total
  item['file']
  item['更新日時'] = Time.now.iso8601
  hb.update item
  logger.info "updated the record"
end

def handle_state params
  lw = LineWorks.instance
  case $session[:state]
  when REGIST_STATE_SHOW_SUMMARY
    slip = $session[:slip]
    send_query_buttons "書類: #{slip.deal_kind}\n取引日: #{slip.deal_at.strftime('%m月%d日')}\n相手先: #{slip.customer}\n金額: #{slip.total}\nで登録しますか？", ["はい", "いいえ"], params
    $session[:state] = REGIST_STATE_SHOW_SUMMARY_RES
  
  when REGIST_STATE_SHOW_SUMMARY_RES
    case params["content"]["postback"]
    when "はい"
      regist_slip
      send_message "登録しました。", params
      reset

    when "いいえ"
      send_query_buttons get_user_id(params), "書類: #{slip.deal_kind}\n取引日: #{slip.deal_at.strftime('%m月%d日')}\n相手先: #{slip.customer}\n金額: #{slip.total}\nで登録しますか？", ["はい", "いいえ"], params
    end

  when REGIST_STATE_QUERY_DEAL_AT
    case params["content"]["postback"]
    when "はい"
    when "いいえ"
    else
      send_message get_user_id(params), "取引日は#{$session[:item]["deal_at"].strftime('%m月%d日')}ですか？", ["はい", "いいえ"], params
    end
  end
end

def dispatch params
p "*" * 40, params, $session
  case params["content"]["type"]
  when "message", "text"
    if $session[:state]
      handle_state params
      return
    end
    case params["content"]["text"]
    when "帳簿登録"
      $session[:state] ||= REGIST_STATE_REQUEST_IMAGE
p $session[:state]
      send_message "画像またはPDFファイルをアップロードしてください。", params
    when "lwbt"
      user_id = get_user_id params
      LineWorks.instance.query_buttons user_id, "選択してね？", ["A", "B"]
    when "text"
      case get_message(params)
      when 'gvt'
        GoogleVision.instance.test
      else
        echo_message params
      end
    end
  when "file", "image"
    regist_file params
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
