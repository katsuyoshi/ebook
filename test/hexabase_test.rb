require 'test_helper'
require './hexabase'
require 'dotenv'

Dotenv.load

class HexabaseTest < Test::Unit::TestCase

  def setup
    @hb = Hexabase.instance
  end

  def test_query
  end

=begin
  def test_clean
    assert_equal [], @hb.clean
  end
=end

end
