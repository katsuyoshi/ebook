require 'json'
require "net/http"

class YahooTextAnalyzer

  attr_reader :tokens

  def analyze text, id = "1"

    uri = URI.parse("https://jlp.yahooapis.jp/MAService/V2/parse")
    header = {
      'Content-Type' => 'application/json',
      'User-Agent' =>  "Yahoo AppID: #{ENV['YAHOO_CLIENT_ID']}"
    }
    payload = {
      'id' => id,
      'jsonrpc' => '2.0',
      'method' => 'jlp.maservice.parse',
      'params' => {
        'q' => text
      }
    }
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.post(uri.path, payload.to_json, header)
    end
    case response
    when Net::HTTPSuccess
      @tokens = JSON.parse(response.body)['result']['tokens']
    else
      nil
    end

  end

  def nouns
    tokens.select{|t| t[3] == '名詞'}.map{|t| t[0]}
  end

  def numbers
    tokens.select{|t| t[4] == '数詞'}.map{|t| t[0]}
  end



end
