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
require "net/http"
require 'singleton'
require 'json/jwt'
require 'base64'
require 'openssl'
require './slip'


# @see: https://zenn.dev/yusukeiwaki/scraps/9882b13700ac82
# @see: https://github.com/googleapis/google-cloud-ruby/blob/main/google-cloud-vision-v1/lib/google/cloud/vision/v1/product_search/credentials.rb

class GoogleVision
  include Singleton

  def logger
    @logger ||= Logger.new('web.log')
  end


  def jwt
    if @jwt_expire_at.nil? || Time.now > @jwt_expire_at
      @jwt = nil
    end
    @jwt ||= begin
      header = {"alg" => "RS256", "typ" => "JWT"}
      @jwt_expire_at = (Time.now + 60 * 60)
      config = JSON.parse(ENV['GOOGLE_APPLICATION_CREDENTIALS_JSON'])
      #config = JSON.parse(File.read(ENV['GOOGLE_APPLICATION_CREDENTIALS_PATH']))
      claim = {
          "iss" => config['client_email'],
          "scope" => "https://www.googleapis.com/auth/cloud-vision",
          "aud" => "https://oauth2.googleapis.com/token",
          "iat" => Time.now.to_i,
          "exp" => @jwt_expire_at.to_i
      }
      jwt = JSON::JWT.new(claim)
      
      private_key = OpenSSL::PKey::RSA.new config['private_key']
      jwt.header = header
      jwt.sign(private_key).to_s
    end
  end

  def access_token
    if @access_token_expired_at.nil? || Time.now > @access_token_expired_at
      @access_token = nil
    end
    @access_token ||= begin
      uri = URI.parse("https://oauth2.googleapis.com/token")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme === "https"
      
      header = {
        'Content-Type' => 'application/json',
      }
        params = {
        'assertion' => jwt,
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      }
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.post(uri.path, params.to_json, header)
      end
      response = Net::HTTP.post_form(uri, params)
      json = JSON.parse(response.body)
      @access_token_expired_at = Time.now + json[""].to_f
      json["access_token"]
    end
  end

  def ocr image, filename = nil
    uri = URI.parse("https://vision.googleapis.com/v1/images:annotate")
    header = {
      "Authorization" => "Bearer #{access_token}",
      'Content-Type' => 'application/json',
    }
    payload = {
      "requests" => [
        {
          "image" => {
            "content" => Base64.strict_encode64(image)
          },
          "features" => [
            "type" => "TEXT_DETECTION",
            "maxResults": 100
          ]
        }
      ]
    }
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.post(uri.path, payload.to_json, header)
    end
    case response
    when Net::HTTPSuccess
      h = JSON.parse(response.body)
      logger.info h
      Slip.new((filename ? "#{filename}\n" : "") + h['responses'].first['textAnnotations'].first['description'])
    else
      nil
    end
=begin
    h = JSON.parse(File.read('annotations.json'))
    Slip.new h['responses'].first['textAnnotations'].first['description']
=end

  end

  def test
    ocr(File.read("sample.jpg"))
  end

end

if $0 == __FILE__
  require 'dotenv'
  Dotenv.load
  gv = GoogleVision.instance
  annotations = gv.ocr(File.read("receipt.jpg"))
  p annotations
  File.write('annotations.json', JSON.dump(annotations))
end
