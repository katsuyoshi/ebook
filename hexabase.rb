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
require "net/http"
require 'singleton'
require 'nokogiri'
require 'active_support/all'

class Time
  def to_hb_iso8601
    self.utc.iso8601.gsub(/Z/, '.000Z')
  end
end


class Hexabase
  include Singleton
  
  def logger
    @logger ||= Logger.new('web.log')
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
    header = {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
    payload = {
      'item' => {
        '????????????' => Time.now.to_hb_iso8601,
        '????????????' => Time.now.to_hb_iso8601,
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
    header = {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }

    item['????????????'] = Time.now.to_hb_iso8601
    #item['rev_no'] = item['rev_no'] + 1
    item.delete 'rev_no'
    payload = {
      'item' => item,
      'return_item_result' => true,
      'return_display_id' => true,
      'ensure_transaction' => true,
      'is_force_update' => true,
    }
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.post(uri.path, payload.to_json, header)
    end
    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)["item"]
    else
      nil
    end
  end

  def query_item item
    app_id = URI.encode_www_form_component(ENV['HEXABASE_PROJECT_DISPLAY_ID'])
    datastore_id = URI.encode_www_form_component(ENV['HEXABASE_DATASTORE_DISPLAY_ID'])
    uri = URI.parse(
            File.join(ENV['HEXABASE_API_SERVER'],
            "/api/v0/applications/#{app_id}/datastores/#{datastore_id}/items/search")
          )
    header = {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
    payload = {
      'conditions' => 
        %w(deal_kind deal_at customer total).map do |k|
          p "item[#{k}] = #{item[k]}"
          if item.keys.include? k
            case k
            when 'deal_at', 'created_at', 'updated_at'
              {
                'id' => k,
                'search_value' => time_search_value_of(item[k]),
              }
            when 'total'
              {
                'id' => k,
                'search_value' => [item[k].to_s],
              }
            else
              {
                'id' => k,
                'search_value' => [item[k]],
              }
            end
          else
            nil
          end
        end.select{|e| e},
      'use_or_condition' => false,
      'per_page' => 0,
      'page' => 1,
      'return_number_value' => true,
      'use_display_id' => true,
    }

    logger.info payload
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.post(uri.path, payload.to_json, header)
    end
    case response
    when Net::HTTPSuccess
      json = JSON.parse(response.body)
      json["items"]
    else
      nil
    end
  end

  def delete items
    case items
    when Array
      return items.each{|i| delete i}
    end

    app_id = URI.encode_www_form_component(ENV['HEXABASE_PROJECT_DISPLAY_ID'])
    datastore_id = URI.encode_www_form_component(ENV['HEXABASE_DATASTORE_DISPLAY_ID'])
    item_id = items["i_id"]
    uri = URI.parse(
            File.join(ENV['HEXABASE_API_SERVER'],
            "/api/v0/applications/#{app_id}/datastores/#{datastore_id}/items/delete/#{item_id}")
          )
    header = {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
#=begin
    s = "curl -X DELETE -d \"#{{}.to_json}\" #{header.map{|k,v| '-H "' + k + ':' + v + '" '}.join(" ")} #{uri}"
    system(s)
#=end

  # NOTE: body?????????????????????????????????????????????curl?????????
=begin
    payload = {}
    req = Net::HTTP::Delete.new(uri, {})
    req.body = {}.to_json
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
p req.body
      http.request req
    end
p response
    case response
    when Net::HTTPSuccess
      json = JSON.parse(response.body)
    else
      nil
    end
=end
  end

  def clean
    items = query_item 'deal_kind' => nil
    # file_name???????????????????????????????????????
    #items += query_item 'file_name' => nil
    delete items
  end


  private

  def time_search_value_of time
    from = to = nil
    case time
    when '??????'
      from = Time.now.beginning_of_day
      to = from + 1.day
    when '??????'
      from = Time.now.beginning_of_day - 1.day
      to = from + 1.day
    when '?????????'
      from = Time.now.beginning_of_day - 2.days
      to = from + 1.day
    when '??????'
      from = Time.now.beginning_of_day - Time.now.wday.days
      to = from + 7.days
    when '??????', '??????'
      from = Time.now.beginning_of_day - (Time.now.wday + 7).days
      to = from + 7.days
    when '??????'
      from = Time.now.beginning_of_month
      to = from.end_of_month.ceil
    when '??????', '??????'
      from = (Time.now.beginning_of_month - 1.day).beginning_of_month
      to = from.end_of_month.ceil
    when '??????'
      from = Time.now.beginning_of_year
      to = from.end_of_year + 1
    when '??????'
      from = (Time.now.beginning_of_year - 1.day).beginning_of_year
      to = from.end_of_year.ceil
    when '?????????'
      from = ((Time.now.beginning_of_year - 1.day).beginning_of_year - 1.day).beginning_of_year
      to = from.end_of_year.ceil
    when /(\d{1,4})???/
      to = Time.now.end_of_day.ceil
      from = to - $1.to_i.days
    when /(\d{1,2})???/
      y = Time.now.year
      from = Time.new(y, $1.to_i, 1)
      from = Time.new(y - 1, $1.to_i, 1) if Time.now < from
      to = from.end_of_month.ceil
    when /(\d{4})\s*\/\s*(\d{1,2})\s*\/\s*(\d{1,2})\s*\-(\s*(\d{4})\s*\/)?\s*(\d{1,2})\s*\/\s*(\d{1,2})/
      from = Time.new($1.to_i, $2.to_i, $3.to_i)
      y = from.year
      to =  Time.new(($5||y).to_i, $6.to_i, $7.to_i)
      to =  Time.new(($5||y + 1).to_i, $6.to_i, $7.to_i) if to < from
    when /(\d{1,2})\s*\/\s*(\d{1,2})\s*\-\s*(\d{1,2})\s*\/\s*(\d{1,2})/
      y = Time.now.year
      from = Time.new(y, $1.to_i, $2.to_i)
      to =  Time.new(y, $3.to_i, $4.to_i)
      to =  Time.new(y + 1, $3.to_i, $4.to_i) if to < from
    else
      from = time
    end

    if from && from.class == Time
      from = from.to_hb_iso8601
    end
    if to && to.class == Time
      to = to.to_hb_iso8601
    end
    if to
      [from, to]
    else
      [from]
    end

  end

end


if $0 == __FILE__
  require 'dotenv'
  Dotenv.load
  hb = Hexabase.instance
  hb.clean; exit
=begin
  item = hb.create
  p item
=end
  item = {}
  item['file_name'] = File.basename(__FILE__)
  item['deal_kind'] = '?????????'
  item['deal_at'] = Date.today.to_time
  item['customer'] = 'Summy'
  item['total'] = 1234

#  item = hb.update item

  p item
  #item['deal_at'] = Time.parse(item['deal_at'])
  hb.query_item item
end
