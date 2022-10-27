require 'json'
require 'time'
require 'json/jwt'
require 'base64'
require "net/http"
require 'singleton'

class LineWorks
  include Singleton

  def jwt
    @jwt ||= begin
      private_key = OpenSSL::PKey::RSA.new ENV['LINEWORKS_PRIVATE_KEY']
      header = {"alg" => "RS256", "typ" => "JWT"}
      claim = {
          "iss" => ENV['LINEWORKS_CLIENT_ID'],
          "sub" => ENV['LINEWORKS_SERVICE_ACCOUNT'],
          "iat" => Time.now.to_i,
          "exp" => (Time.now + 60 * 60).to_i
      }
      jwt = JSON::JWT.new(claim)
      
      jwt.header = header
      jwt.sign(private_key).to_s
    end
  end

  def access_token
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
      JSON.parse(response.body)["access_token"]
    end
  end
    
end
