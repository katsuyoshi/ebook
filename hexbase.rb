require 'json'
require 'time'
require "net/http"
require 'singleton'
require 'nokogiri'

# @see: https://github.com/nov/json-jwt


class Hexbase
  include Singleton
  
  def logger
    @logger ||= Logger.new('sinatra.log')
  end

  def token
    @token ||= begin
      uri = URI.parse(File.join(ENV['HEXABASE_API_SERVER'], '/api/v0/login'))
      header = {
        'Content-Type' => 'application/json'
      }
      payload = {
        "email": ENV['HEXABASE_EMAIL'],
        "password": ENV['HEXABASE_PASSWORD'],
      }
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.post(uri.path, payload.to_json, header)
      end
      p response
      case response
      when Net::HTTPSuccess, Net::HTTPRedirection
        JSON.parse(response.body)['token']
      else
        nil
      end
    end
  end

  def create
    app_id = URI.encode(ENV['HEXABASE_PROJECT_DISPLAY_ID'])
    datastore_id = URI.encode(ENV['HEXABASE_DATASTORE_DISPLAY_ID'])
    uri = URI.parse(
            File.join(ENV['HEXABASE_API_SERVER'],
            "/api/v0/applications/#{app_id}/datastores/#{datastore_id}/items/new")
    )
    p uri
    header = {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
    payload = {
      'item' => {
        '作成日時' => Time.now.iso8601,
        '更新日時' => Time.now.iso8601,
      },
      'return_item_result' => true,
      'return_display_id' => true,
      'ensure_transaction' => true,
    }
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.post(uri.path, payload.to_json, header)
    end
    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      JSON.parse(response.body)["item"]
    else
      nil
    end
  end

end


if $0 == __FILE__
  require 'dotenv'
  hb = Hexbase.instance
  Dotenv.load
    #p hb.token
    p hb.create
end
