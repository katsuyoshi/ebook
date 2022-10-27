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
  'OK'
end
