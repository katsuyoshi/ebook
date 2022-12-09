# MIT License
# 
# Copyright (c) 2022 Katsuyoshi Ito
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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
    @logger ||= Logger.new('web.log')
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

  def send_link title, url, userId
    botId = ENV['LINEWORKS_BOT_ID']
    uri = URI.parse("https://www.worksapis.com/v1.0/bots/#{botId}/users/#{userId}/messages")
    header = {
      "Authorization" => "Bearer #{access_token}",
      "Content-Type" => "application/json"
    }
    payload = {
      "content" => {
        "type" => "button_template",
        "contentText" => title,
        "actions" => [
          {
          "type" => "uri",
          "label" => title,
          "uri" => url,
          }
        ]
      }
    }
p payload
    response = Net::HTTP.post(uri, payload.to_json, header)
p response, response.body
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

  def upload_file path, filename
    botId = ENV['LINEWORKS_BOT_ID']
    uri = URI.parse("https://www.worksapis.com/v1.0/bots/#{botId}/attachments")

    header = {
      "Authorization" => "Bearer #{access_token}",
      "Content-Type" => "application/json"
    }
    payload = {
      'fileName' => filename
    }
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.post(uri, payload.to_json, header)
    end
    case response
    when Net::HTTPSuccess
      r = JSON.parse(response.body)

      s = "curl -XPOST '#{r['uploadUrl']}' -H 'Authorization: Bearer #{access_token}' -H 'Content-Type: multipart/form-data' -F 'resourceName=#{filename}' -F 'FileData=@#{path}'"
p s
      system(s)


=begin
      uri = URI.parse(r['uploadUrl'])
      boundary='----WebKitFormBoundary7MA4YWxkTrZu0gW'
      header = {
        "Authorization" => "Bearer #{access_token}",
        "Content-Type" => "multipart/form-data; boundary=#{boundary}"
      }
  
      req = Net::HTTP::Post.new(uri.request_uri)
=end

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

