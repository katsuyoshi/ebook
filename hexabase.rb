require 'json'
require 'time'
require "net/http"
require 'singleton'
require 'nokogiri'

class Hexabase
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
      when Net::HTTPSuccess
        JSON.parse(response.body)['token']
      else
        nil
      end
    end
  end

  def create
    app_id = URI.encode_www_form_component(ENV['HEXABASE_PROJECT_DISPLAY_ID'])
    datastore_id = URI.encode_www_form_component(ENV['HEXABASE_DATASTORE_DISPLAY_ID'])
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
    when Net::HTTPSuccess
      json = JSON.parse(response.body)
      p json
      json["item"]
    else
      nil
    end
  end

  def update item
    app_id = URI.encode_www_form_component(ENV['HEXABASE_PROJECT_DISPLAY_ID'])
    datastore_id = URI.encode_www_form_component(ENV['HEXABASE_DATASTORE_DISPLAY_ID'])
    item_id = item["i_id"]
    uri = URI.parse(
            File.join(ENV['HEXABASE_API_SERVER'],
            "/api/v0/applications/#{app_id}/datastores/#{datastore_id}/items/edit/#{item_id}")
    )
    p uri
    header = {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }

    item['更新日時'] = Time.now.iso8601
    #item['rev_no'] = item['rev_no'] + 1
    item.delete 'rev_no'
    payload = {
      'item' => item,
      'return_item_result' => true,
      'return_display_id' => true,
      'ensure_transaction' => true,
      'is_force_update' => true,
    }
    p payload
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.post(uri.path, payload.to_json, header)
    end
    p response
    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)["item"]
    else
      nil
    end
  end

end


if $0 == __FILE__
  require 'dotenv'
  Dotenv.load
  hb = Hexabase.instance
  item = hb.create
  p item
  item['file_name'] = File.basename(__FILE__)
  item = hb.update item
  p item
end
