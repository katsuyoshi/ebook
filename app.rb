require 'sinatra'
require 'sinatra/reloader'
require 'logger'
require 'base64'
require 'openssl'
require 'rmagick'
require 'time'
require 'fileutils'

require 'dotenv'
Dotenv.load
require './lineworks'
require './hexabase'
require './s3'
require './google_vision'

include FileUtils

#enable :sessions


logger = Logger.new('sinatra.log')

token = LineWorks.instance.access_token


REGIST_STATE_IDLE                 = 0
REGIST_STATE_REQUEST_IMAGE        = 1
REGIST_STATE_UPLOADING            = 2
REGIST_STATE_SHOW_SUMMARY         = 3
REGIST_STATE_SHOW_SUMMARY_RES     = 4
REGIST_STATE_DUPPLICATED_RES      = 5
REGIST_STATE_SELECT_EDIT_PROPERTY = 6
REGIST_STATE_EDIT_DEAL_KIND       = 7
REGIST_STATE_EDIT_DEAL_AT         = 8
REGIST_STATE_EDIT_CUSTOMER        = 9
REGIST_STATE_EDIT_TOTAL           = 10

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
  file_id = get_file_id params
  file_info = LineWorks.instance.download_file file_id
  unless %w(png jpg jpeg pdf).include?(File.extname(file_info[:file_name])[1..-1])
    send_message '画像またはPDFファイルをアップロードしてください。', params
    return
  end

  # create new record
  hb = Hexabase.instance
  item = hb.create
  lw.send_message user_id, 'レコードを作りました。'
  $session[:item] = item
  logger.info item

  # store file to S3 bucket
  s3 = S3.instance
  path = s3.upload(file_info[:file_data], File.join(item['record_no'], file_info[:file_name]))
  lw.send_message user_id, 'ファイルを登録しました。'

  # update record
  item["file_url"] = path
  item["file_name"] = file_info[:file_name]

  # processing image
  gv = GoogleVision.instance
  dst = File.join("./tmp/#{file_info[:file_name]}")
  mkdir_p File.dirname(dst)
  File.write dst, file_info[:file_data]
  image = Magick::Image.read(dst).first
  if /pdf$/i =~ File.extname(file_info[:file_name])[1..-1]
    File.write('./tmp/image.pdf', image)
    image = Magick::Image.read('./tmp/image.pdf').first do
      self.quality = 100
      self.density = 200
    end
  end
  while image.to_blob.bytesize >= 2_000_000
    image = image.resize(0.9)
  end
  slip = gv.ocr image
  $session[:slip] = slip
  lw.send_message user_id, '画像を読み取りました。'
  logger.info slip

  $session[:state] = REGIST_STATE_SHOW_SUMMARY
  handle_state params
end

def send_query_buttons message, candidates, params
  LineWorks.instance.query_buttons get_user_id(params), message, candidates
end

def reset
  $session = {}
end

def regist_slip force = false
  hb = Hexabase.instance

  slip = $session[:slip]
  item = $session[:item]
  item['deal_kind'] = slip.deal_kind
  item['deal_at'] = slip.deal_at
  item['customer'] = slip.customer
  item['total'] = slip.total
  item['file']
  item['更新日時'] = Time.now.to_s

  # check dupplicated
  unless force
    items = hb.query_item item
p items
    return :dupplicated unless items.size == 0
  end

  # update record
  hb.update item
  :ok
end

def handle_state params
  lw = LineWorks.instance
  case $session[:state]
  when REGIST_STATE_SHOW_SUMMARY
    slip = $session[:slip]
    send_query_buttons "書類: #{slip.deal_kind}\n取引日: #{slip.deal_at.strftime('%m月%d日')}\n相手先: #{slip.customer}\n金額: #{slip.total}\nで登録しますか？", ["はい", "いいえ"], params
    $session[:state] = REGIST_STATE_SHOW_SUMMARY_RES
  
  when REGIST_STATE_SHOW_SUMMARY_RES
    case params["content"]["text"]
    when "はい"
      case regist_slip
      when :ok
        send_message "登録しました。", params
        reset
      when :dupplicated
        send_query_buttons "同じ様な書類が登録されています。このまま登録しますか？", ["はい", "いいえ"], params
        $session[:state] = REGIST_STATE_DUPPLICATED_RES
      end

    when "いいえ"
      send_query_buttons "どの項目を変更しますか？", ["書類", "取引日", '相手先', '金額', '登録を中止'], params
      $session[:state] = REGIST_STATE_SELECT_EDIT_PROPERTY
    end

  when REGIST_STATE_DUPPLICATED_RES
    case params["content"]["text"]
    when "はい"
      case regist_slip true
      when :ok
        send_message "登録しました。", params
        reset
      else
        send_message "登録に失敗しました。", params
        reset
      end
    when "いいえ"
      send_message "登録を中止しました。", params
      reset
    end

  
  when REGIST_STATE_SELECT_EDIT_PROPERTY
    case params["content"]["text"]
    when '書類'
      send_query_buttons "書類の種類は？", %w(見積書 注文書 請求書 納品書 領収書), params
      $session[:state] = REGIST_STATE_EDIT_DEAL_KIND
    when '取引日'
      send_message "取引日は？", params
      $session[:state] = REGIST_STATE_EDIT_DEAL_AT
    when '相手先'
      slip = $session[:slip]
      send_query_buttons "相手先は？", slip.candidate_customers[0,2], params
      $session[:state] = REGIST_STATE_EDIT_CUSTOMER
    when '金額'
      send_message "金額は？", params
      $session[:state] = REGIST_STATE_EDIT_TOTAL
    when '登録を中止'
      reset
      send_message "中止しました。", params
    else
      handle_state params
      $session[:state] = REGIST_STATE_SHOW_SUMMARY
    end
  

  when REGIST_STATE_EDIT_DEAL_KIND
    slip = $session[:slip]
    slip.deal_kind = params["content"]["postback"] || params["content"]["text"]
    $session[:state] = REGIST_STATE_SHOW_SUMMARY
    handle_state params

  when REGIST_STATE_EDIT_DEAL_AT
    slip = $session[:slip]
    slip.deal_at = params["content"]["postback"] || params["content"]["text"]
    $session[:state] = REGIST_STATE_SHOW_SUMMARY
    handle_state params

  when REGIST_STATE_EDIT_CUSTOMER
    slip = $session[:slip]
    slip.customer = params["content"]["postback"] || params["content"]["text"]
    $session[:state] = REGIST_STATE_SHOW_SUMMARY
    handle_state params

  when REGIST_STATE_EDIT_TOTAL
    slip = $session[:slip]
    slip.total = params["content"]["postback"] || params["content"]["text"]
    $session[:state] = REGIST_STATE_SHOW_SUMMARY
    handle_state params

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

  dispatch params

  'OK'
end
