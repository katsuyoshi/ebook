require 'sinatra'
require 'dotenv'
Dotenv.load

require './lineworks'


token = LineWorks.instance.access_token

get '/' do
  'Hello world!'
end