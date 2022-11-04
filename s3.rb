require 'json'
require 'time'
require 'singleton'
require 'aws-sdk-core'
require 'aws-sdk-s3'

class S3
  include Singleton
  
  def initialize
    Aws.config.update(
      region: ENV['AWS_REGION'],
      credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
    )
    @s3 = Aws::S3::Resource.new
    @bucket = @s3.bucket(ENV['S3_BUCKET_NAME'])
  end

  def list
    @bucket.objects.each do |obj|
      puts "#{obj.key} => #{obj.etag}"
    end
  end

  def upload data, path
    obj = @bucket.object(path)
    obj.put(body:  data)
    "https://#{ENV['S3_BUCKET_NAME']}.s3.amazonaws.com/#{path}"
  end

  def logger
    @logger ||= Logger.new('web.log')
  end

end


if $0 == __FILE__
  require 'dotenv'
  Dotenv.load
  s3 = S3.instance
  s3.list
  p s3.upload(File.read(__FILE__), File.basename(__FILE__))
end
  