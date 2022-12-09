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
