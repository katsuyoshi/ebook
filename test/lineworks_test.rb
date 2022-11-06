require 'test_helper'
require './lineworks'
require 'dotenv'
require 'fileutils'
require 'rmagick'

include FileUtils


Dotenv.load

class LineWorksTest < Test::Unit::TestCase

  def setup
    @lw = LineWorks.instance

    @path = File.join("tmp", "rectangle.jpg")
    image = Magick::Image.new(640, 480)
    image.write @path
    #@path = File.join("tmp", "吾輩は猫である.txt")
    #File.write @path, "吾輩は猫である"
  end

  def teardown
    File.delete @path if File.exist? @path
  end

=begin
  def test_upload_file
    assert_nothing_thrown do
      @lw.upload_file @path, File.basename(@path)
    end
  end
=end

  def test_send_link
    assert_nothing_thrown do
      @lw.upload_file @path, File.basename(@path)
    end
  end


  
end
