require 'json'
require "net/http"
require 'singleton'
require 'base64'

class GoogleVision
  include Singleton
  
  def ocr image
    uri = URI.parse("https://vision.googleapis.com/v1/images:annotate?key=#{ENV['GOOGLE_VISION_API_KEY']}")
    header = {
      'Content-Type' => 'application/json',
      'Referer' => 'https://itosoft.com/'
    }
    p uri
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
    p response.body
    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)
    else
      nil
    end

  end

  def test
    ocr(File.read("sample.jpg"))
  end

end

if $0 == __FILE__
  require 'dotenv'
  Dotenv.load
  gv = GoogleVision.instance
  annotations = gv.ocr(File.read("sample.jpg"))
  p annotations
end
