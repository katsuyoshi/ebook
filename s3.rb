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
  