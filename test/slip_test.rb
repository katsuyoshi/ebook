require 'test_helper'
require './slip'

class SlipTest < Test::Unit::TestCase

  def setup
    @slip = Slip.new "株式会社いろは\n請求書\n123-456-7890\nno_reply@example.com\n123-4567\nxxxx\n1-2-34\n8: 123-4567\nxx県xx市xx町1-2-34\n株式会社にほへと\n部署名\n加納尚子様\n日付: 11月3日\nプロジェクトタイトル: プロジェクト名\nプロジェクトの説明: 説明を記入\n注文番号: 12345\n請求書番号: 67890\n詳細\n項目1\n項目2\n項目3\n数量\n1\n税額\n55\n13\n25\n単価\n¥100.00\n¥90.00\n¥50.00\n小計\n合計\n10.00%\nお世話になっております。 プロジェクトでご一緒できて光栄です。\n次のご注文は30日以内に出荷されます。\n今後ともよろしくお願いします。\n永田次郎\n(株)いろは\n(有)いろは\n（株）いろは\n（有）にほへと"
  end

  def test_candidate_customer
    expected = [
      '株式会社いろは',
      '株式会社にほへと',
      '(株)いろは',
      '(有)いろは',
      '（株）いろは',
      '（有）にほへと',
    ]
    assert_equal expected, @slip.candidate_customers
  end

  def test_customer
    assert_equal '株式会社いろは', @slip.customer
  end

  def test_candidate_deal_at
    expected = [ Time.new(2022,1,2), Time.new(2022, 11, 3)].reverse
    assert_equal expected, @slip.candidate_deal_at
  end

  def test_candidate_total
    assert_equal [100, 90, 50], @slip.candidate_total
  end

end

class SlipCompanyTest < Test::Unit::TestCase

  def setup
    @slip = Slip.new "株式会社いろは\n有限会社にほへと\n(株)いろは\n(有)いろは\n（株）いろは\n（有）にほへと\n合同会社いろは\n税理士法人にほへと\nいろはInc.\nにほへとCO'LTD"
  end

  def test_candidate_customer
    expected = [
      '株式会社いろは',
      '有限会社にほへと',
      '(株)いろは',
      '(有)いろは',
      '（株）いろは',
      '（有）にほへと',
      '合同会社いろは',
      '税理士法人にほへと',
      'いろはInc.',
      'にほへとCO\'LTD',
    ]
    assert_equal expected, @slip.candidate_customers
  end

end

class SlipDealAtTest < Test::Unit::TestCase

  def setup
    @slip = Slip.new "2022年1月2日\n2022年02月03日\n3月4日\n5月6日\n2022/1/3\n2022/02/04\n3/5/2022\n3/5\n2022-1-4\n2022-01-04\n1-5\n1-4-2022\n"
  end

  def test_candidate_deal_at
    expected = [
      Time.new(2022,1,2),
      Time.new(2022,1,3),
      Time.new(2022,1,4),
      Time.new(2022,1,5),
      Time.new(2022,2,3),
      Time.new(2022,2,4),
      Time.new(2022,3,4),
      Time.new(2022,3,5),
      Time.new(2022,5,6),
    ].reverse
    assert_equal expected, @slip.candidate_deal_at
  end

end
