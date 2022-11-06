require 'sinatra'
require 'sinatra/reloader'
require 'logger'
require 'base64'
require 'openssl'
require 'rmagick'
require 'time'
require 'fileutils'
require 'csv'
require 'securerandom'


require 'dotenv'
Dotenv.load
require './lineworks'
require './hexabase'
require './s3'
require './google_vision'

include FileUtils

#enable :sessions


logger = Logger.new('web.log')

token = LineWorks.instance.access_token


REGIST_STATE_IDLE                 = 0
REGIST_STATE_REQUEST_IMAGE        = 1
REGIST_STATE_UPLOADING            = 2
REGIST_STATE_SHOW_SUMMARY         = 3
REGIST_STATE_SHOW_SUMMARY_RES     = 4
REGIST_STATE_DUPPLICATED_RES      = 5
REGIST_STATE_EDIT_DEAL_KIND       = 6
REGIST_STATE_EDIT_DEAL_AT         = 7
REGIST_STATE_EDIT_CUSTOMER        = 8
REGIST_STATE_EDIT_TOTAL           = 9
REGIST_STATE_QUERY_REPEAT         = 10
REGIST_STATE_QUERY_REPEAT_RES     = 11

QUERY_STATE_SHOW_SUMMARY          = 100
QUERY_STATE_SHOW_SUMMARY_RES      = 101
QUERY_STATE_EDIT_DEAL_KIND        = 102
QUERY_STATE_EDIT_DEAL_AT          = 103
QUERY_STATE_EDIT_DEAL_CUSTOMER    = 104
QUERY_STATE_EDIT_DEAL_TOTAL       = 105
QUERY_STATE_SHOW_RESULT           = 106
QUERY_STATE_SHOW_RESULT_RES       = 107

QUERY_RESULT_VIEW_SIZE            = 5

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

def send_link title, url, params
  user_id = get_user_id params
  res = LineWorks.instance.send_link title, url, user_id
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

  # download file from Lineworks
  file_id = get_file_id params
  file_info = LineWorks.instance.download_file file_id
  unless %w(png jpg jpeg pdf).include?(File.extname(file_info[:file_name])[1..-1])
    send_message '画像またはPDFファイルをアップロードしてください。', params
    return
  end
  logger.info "downloaded a file"

  # create new record
  logger.info "creating a new record"
  hb = Hexabase.instance
  item = hb.create
  lw.send_message user_id, 'レコードを作りました。'
  $session[:item] = item
p item
  logger.info "created a new record"
  logger.info item

  # store file to S3 bucket
  s3 = S3.instance
p [item['record_no'], file_info[:file_name]]
  path = s3.upload(file_info[:file_data], File.join(item['record_no'], file_info[:file_name]))
  lw.send_message user_id, 'ファイルを登録しました。'

  # update record
  item["file_url"] = path
  item["file_name"] = file_info[:file_name]

  # processing image
  gv = GoogleVision.instance
  image = Magick::Image.from_blob(file_info[:file_data]).first
  if /pdf/i =~ image.format
    image = Magick::Image.from_blob(file_info[:file_data]).first# do
    #  self.quality = 100
    #  self.density = 200
    #end
  end
  image.format = 'jpg'
  while image.to_blob.bytesize >= 2_000_000
    image = image.resize(0.9)
  end
  slip = gv.ocr image.to_blob(), file_info[:file_name]
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

p slip, item
  # check dupplicated
  unless force
    items = hb.query_item item
    return :dupplicated unless items.size == 0
  end

  # update record
  hb.update item
  :ok
end


def description_of item
  a = []
  a << "書類: #{item['deal_kind']}" if item['deal_kind']
  a << "取引日: #{item['deal_at']}" if item['deal_at']
  a << "相手先: #{item['customer']}" if item['customer']
  a << "金額: #{item['total']}円" if item['total']
  a.join("\n")
end

def short_description_of item
  a = []
  a << "#{item['deal_kind']}" if item['deal_kind']
  a << "#{item['deal_at']}" if item['deal_at']
  a << "#{item['customer']}" if item['customer']
  a << "#{item['total']}円" if item['total']
  a.join(", ")
end


def query_item
  hb = Hexabase.instance
  item = $session[:item]
  $session[:items] = hb.query_item item
  $session[:items_index] = 0
end

  

def handle_state params
  lw = LineWorks.instance
  case $session[:state]
  when REGIST_STATE_REQUEST_IMAGE
    case params["content"]["text"]

    when "中止する"
      send_message "中止しました。", params
      reset
      Hexabase.instance.clean
    end

  when REGIST_STATE_SHOW_SUMMARY
    slip = $session[:slip]
    send_query_buttons "書類: #{slip.deal_kind}\n取引日: #{slip.deal_at.strftime('%m月%d日') if slip.deal_at}\n相手先: #{slip.customer}\n金額: #{slip.total}\nで登録しますか？", ["登録します", "種類を修正します", "取引日を修正します", "相手先を修正します", "金額を修正します", "登録を中止します"], params
    $session[:state] = REGIST_STATE_SHOW_SUMMARY_RES
  
  when REGIST_STATE_SHOW_SUMMARY_RES
    case params["content"]["text"]
    when "登録します"
      case regist_slip
      when :ok
        send_message "登録しました。", params
        $session[:state] = REGIST_STATE_QUERY_REPEAT
        handle_state params
        when :dupplicated
        send_query_buttons "同じ様な書類が登録されています。このまま登録しますか？", ["はい", "いいえ"], params
        $session[:state] = REGIST_STATE_DUPPLICATED_RES
      end

    when '種類を修正します'
      send_query_buttons "書類の種類は？", %w(見積書 注文書 請求書 納品書 領収書), params
      $session[:state] = REGIST_STATE_EDIT_DEAL_KIND
    when '取引日を修正します'
      send_message "取引日は？", params
      $session[:state] = REGIST_STATE_EDIT_DEAL_AT
    when '相手先を修正します'
      slip = $session[:slip]
      send_query_buttons "相手先は？", slip.candidate_customers[0,2], params
      $session[:state] = REGIST_STATE_EDIT_CUSTOMER
    when '金額を修正します'
      send_message "金額は？", params
      $session[:state] = REGIST_STATE_EDIT_TOTAL
    when '登録を中止します'
      $session[:state] = REGIST_STATE_QUERY_REPEAT
      handle_state params
    else
      $session[:state] = REGIST_STATE_SHOW_SUMMARY
    end

  when REGIST_STATE_DUPPLICATED_RES
    case params["content"]["text"]
    when "はい"
      case regist_slip true
      when :ok
        send_message "登録しました。", params
        $session[:state] = REGIST_STATE_QUERY_REPEAT
        handle_state params
      else
        send_message "登録に失敗しました。", params
        $session[:state] = REGIST_STATE_QUERY_REPEAT
        handle_state params
      end
    when "いいえ"
      send_message "登録を中止しました。", params
      $session[:state] = REGIST_STATE_QUERY_REPEAT
      handle_state params
    end

  when REGIST_STATE_EDIT_DEAL_KIND
    slip = $session[:slip]
    slip.deal_kind = params["content"]["postback"] || params["content"]["text"]
    $session[:state] = REGIST_STATE_SHOW_SUMMARY
p $session
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

  when REGIST_STATE_QUERY_REPEAT
    $session[:state] = REGIST_STATE_REQUEST_IMAGE
    send_query_buttons "画像またはPDFファイルをアップロードしてください。", ["中止する"], params




  when QUERY_STATE_SHOW_SUMMARY
p __LINE__, $session
    item = $session[:item] || {}
    m = description_of(item)
    buttons = %w(種類条件を修正します 取引日条件を修正します 相手先条件を修正します 金額条件を修正します 検索を中止します)
    
    buttons = ['検索します'] + buttons unless m.empty?
    m = m.empty? ? "検索条件を入力してください" : "検索条件は以下のとおりです\n" + m
    p [m, buttons]

    send_query_buttons m, buttons, params
    $session[:state] = QUERY_STATE_SHOW_SUMMARY_RES

  when QUERY_STATE_SHOW_SUMMARY_RES
    case params["content"]["text"]
    when "検索します"
      query_item
      $session[:state] = QUERY_STATE_SHOW_RESULT
      handle_state params

    when '種類条件を修正します'
      send_query_buttons "書類の種類は？", %w(見積書 注文書 請求書 納品書 領収書), params
      $session[:state] = QUERY_STATE_EDIT_DEAL_KIND
 
    when '取引日条件を修正します'
      send_message "取引日条件は？", params
      $session[:state] = QUERY_STATE_EDIT_DEAL_AT
 
    when '相手先条件を修正します'
      send_message "相手先条件は？", params
      $session[:state] = QUERY_STATE_EDIT_DEAL_CUSTOMER
 
    when '金額条件を修正します'
      send_message "金額条件は？", params
      $session[:state] = QUERY_STATE_EDIT_DEAL_TOTAL

    when '検索を中止します'
      send_message "検索を終了しました", params
      reset

    end
 
  when QUERY_STATE_EDIT_DEAL_KIND
    item = $session[:item] || {}
    item['deal_kind'] = params["content"]["postback"] || params["content"]["text"]
    $session[:item] = item
    $session[:state] = QUERY_STATE_SHOW_SUMMARY
    handle_state params

  when QUERY_STATE_EDIT_DEAL_AT
    item = $session[:item] || {}
    item['deal_at'] = params["content"]["postback"] || params["content"]["text"]
    $session[:item] = item
    $session[:state] = QUERY_STATE_SHOW_SUMMARY
    handle_state params

  when QUERY_STATE_EDIT_DEAL_CUSTOMER
    item = $session[:item] || {}
    item['customer'] = params["content"]["postback"] || params["content"]["text"]
    $session[:item] = item
    $session[:state] = QUERY_STATE_SHOW_SUMMARY
    handle_state params

  when QUERY_STATE_EDIT_DEAL_TOTAL
    item = $session[:item] || {}
    item['total'] = params["content"]["postback"] || params["content"]["text"]
    $session[:item] = item
    $session[:state] = QUERY_STATE_SHOW_SUMMARY
    handle_state params

  when QUERY_STATE_SHOW_RESULT
    items = $session[:items]
    index = $session[:items_index]
    view = items[index...(index + QUERY_RESULT_VIEW_SIZE)]

    m = if view.empty?
      m = "該当レコードはありません"
    else
      view.map{|i| short_description_of i}.join('\n')
    end

    buttons = []
    unless view.empty?
      buttons << "前のデータを見る" unless index == 0
      buttons << "次のデータを見る" if index + QUERY_RESULT_VIEW_SIZE < items.size
      buttons << "CSVファイルをダウンロードする"
    end
    buttons << "終了する"
    send_query_buttons m, buttons, params
    $session[:state] = QUERY_STATE_SHOW_RESULT_RES

  when QUERY_STATE_SHOW_RESULT_RES
    case params["content"]["text"]
    when "前のデータを見る"
      $session[:index] -= QUERY_RESULT_VIEW_SIZE
      $session[:state] = QUERY_STATE_SHOW_RESULT
      handle_state params

    when "次のデータを見る"
      $session[:index] += QUERY_RESULT_VIEW_SIZE
      $session[:state] = QUERY_STATE_SHOW_RESULT
      handle_state params
    
    when "CSVファイルをダウンロードする"
      csv_string = CSV.generate do |csv|
        csv << %w(取引日 書類 相手先 金額 ファイルURL)
        $session[:items].each do |item|
          csv << %w(deal_at deal_kind customer total file_url).map{|k| item[k]}
        end
      end
      path = File.join('csv', "#{SecureRandom.uuid}.csv")
      url = S3.instance.upload(csv_string, path)
p "*" * 40
      send_link "CSVファイル", url, params
      reset
      $session[:state] = QUERY_STATE_SHOW_SUMMARY
      handle_state params

    when "終了する"
      reset
      $session[:state] = QUERY_STATE_SHOW_SUMMARY
      handle_state params

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
      send_query_buttons "画像またはPDFファイルをアップロードしてください。", ["中止する"], params

    when '帳簿検索'
      $session[:state] ||= QUERY_STATE_SHOW_SUMMARY
      handle_state params
      
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
