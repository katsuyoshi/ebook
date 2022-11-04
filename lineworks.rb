require 'json'
require 'time'
require 'json/jwt'
require 'base64'
require "net/http"
require 'singleton'
require 'nokogiri'
require 'openssl'
require 'dotenv'

# @see: https://github.com/nov/json-jwt


class LineWorks
  include Singleton
  
  def logger
    @logger ||= Logger.new('sinatra.log')
  end

  def jwt
    if @jwt_expire_at.nil? || Time.now > @jwt_expire_at
      @jwt = nil
    end
    @jwt ||= begin
      private_key = OpenSSL::PKey::RSA.new ENV['LINEWORKS_PRIVATE_KEY']
      header = {"alg" => "RS256", "typ" => "JWT"}
      @jwt_expire_at = (Time.now + 60 * 60)
      claim = {
          "iss" => ENV['LINEWORKS_CLIENT_ID'],
          "sub" => ENV['LINEWORKS_SERVICE_ACCOUNT'],
          "iat" => Time.now.to_i,
          "exp" => @jwt_expire_at.to_i
      }
      jwt = JSON::JWT.new(claim)
      
      jwt.header = header
      jwt.sign(private_key).to_s
    end
  end

  def access_token
    if @access_token_expired_at.nil? || Time.now > @access_token_expired_at
      @access_token = nil
    end
    @access_token ||= begin
      uri = URI.parse("https://auth.worksmobile.com/oauth2/v2.0/token")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme === "https"
      
      params = {
        'assertion' => jwt,
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'client_id' => ENV['LINEWORKS_CLIENT_ID'],
        'client_secret' => ENV['LINEWORKS_CLIENT_SECRET'],
        'scope' => 'bot'
      }
      response = Net::HTTP.post_form(uri, params)
      json = JSON.parse(response.body)
      @access_token_expired_at = Time.now + json[""].to_f
      json["access_token"]
    end
  end

  def send_message userId, message
    botId = ENV['LINEWORKS_BOT_ID']
    uri = URI.parse("https://www.worksapis.com/v1.0/bots/#{botId}/users/#{userId}/messages")
    header = {
      "Authorization" => "Bearer #{access_token}",
      "Content-Type" => "application/json"
    }
    payload = {
      "content" => {
        "type" => "text",
        "text" => message
      }
    }
    response = Net::HTTP.post(uri, payload.to_json, header)
  end

  def query_buttons userId, message, candidates
    botId = ENV['LINEWORKS_BOT_ID']
    uri = URI.parse("https://www.worksapis.com/v1.0/bots/#{botId}/users/#{userId}/messages")
    header = {
      "Authorization" => "Bearer #{access_token}",
      "Content-Type" => "application/json"
    }
    payload = {
      "content" => {
        "type" => "button_template",
        "contentText" => message,
        "actions" => candidates.map do |t|
          {
            "type" => "message",
            "label" => t[0,20],
            "postback" => t,
          }
        end
      }
    }
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.post(uri, payload.to_json, header)
    end
    response
  end

  def download_file fileId
    # get file path
    botId = ENV['LINEWORKS_BOT_ID']
    uri = URI.parse("https://www.worksapis.com/v1.0/bots/#{botId}/attachments/#{fileId}")
    header = {
      "Authorization" => "Bearer #{access_token}",
    }
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.get(uri.path, header)
    end

    # download file
    path = Nokogiri::HTML(response.body).search('a').first['href']
    fname = URI.decode_www_form(path.split("/")[-2]).first.first
    uri = URI.parse(path)
    logger.info uri

    header = {
      "Authorization" => "Bearer #{access_token}",
    }
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.get(uri.path, header)
    end
    logger.info response

    {
      file_name: fname,
      file_data: response.body
    }
  end

  def bot_menu
    botId = ENV['LINEWORKS_BOT_ID']
    uri = URI.parse("https://www.worksapis.com/v1.0/bots/#{botId}/persistentmenu")
    header = {
      "Authorization" => "Bearer #{access_token}",
      "Content-Type" => "application/json"
    }
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.get(uri, header)
    end
    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)['content']
    else
      nil
    end
  end

  def regist_bot_menu
    content = bot_menu
    action1 = {
      'type' => 'message',
      'label' => '帳簿登録'
    }
    action2 = {
      'type' => 'message',
      'label' => '帳簿検索'
    }
    actions = content['actions']
    changed = false
    unless actions.include? action1
      actions << action1
      changed = true
    end
    unless actions.include? action2
      actions << action2
      changed = true
    end
    return unless changed

    botId = ENV['LINEWORKS_BOT_ID']
    uri = URI.parse("https://www.worksapis.com/v1.0/bots/#{botId}/persistentmenu")
    header = {
      "Authorization" => "Bearer #{access_token}",
      "Content-Type" => "application/json"
    }
    payload = {
      'content' => {
        'actions' => actions,
      }
    }
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.post(uri, payload.to_json, header)
    end
    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)['content']
    else
      nil
    end

  end
    
end


if $0 == __FILE__
  Dotenv.load
  lw = LineWorks.instance
  lw.regist_bot_menu
end

