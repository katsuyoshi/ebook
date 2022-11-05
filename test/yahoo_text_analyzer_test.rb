__END__
require 'test_helper'
require './yahoo_text_analyzer'

class YahooTextAnalyzerTest < Test::Unit::TestCase

  def setup
    @analyzer = YahooTextAnalyzer.new
  end

  def test_bottyan
    @analyzer.analyze("吾輩は猫である。")
    assert_equal 5, @analyzer.tokens.size
    assert_equal %w(吾輩 猫), @analyzer.nouns
  end

end
