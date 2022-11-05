require 'test_helper'
require './hexabase'
require 'dotenv'
require 'mocha/test_unit'
require 'active_support/all'


Dotenv.load

class Hexabase
  def _time_search_value_of t; time_search_value_of t; end
end

class HexabaseTest < Test::Unit::TestCase

  def setup
    @hb = Hexabase.instance
  end

  def test_query_customer
    Time.stubs(:now).returns(Time.local(2022,11,4))
    assert_equal(1, @hb.query_item('customer' => '秋月電子').size)
  end

  def test_query_deal_at_last_month
    Time.stubs(:now).returns(Time.local(2022,11,4))
    assert_equal([], @hb.query_item('deal_at' => '先月'))
  end

  def test_query_deal_kind_order
    Time.stubs(:now).returns(Time.local(2022,11,4))
    assert_equal(1, @hb.query_item('deal_kind' => '注文書').size)
  end

  def test_time_condition_today
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2022, 11, 4).beginning_of_day.to_hb_iso8601,
      Time.new(2022, 11, 5).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("今日")
  end

  def test_time_condition_yesterday
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2022, 11, 3).beginning_of_day.to_hb_iso8601,
      Time.new(2022, 11, 4).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("昨日")
  end

  def test_time_condition_day_before_yesterday
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2022, 11, 2).beginning_of_day.to_hb_iso8601,
      Time.new(2022, 11, 3).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("一昨日")
  end

  def test_time_condition_this_week
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2022, 10, 30).beginning_of_day.to_hb_iso8601,
      Time.new(2022, 11, 6).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("今週")
  end

  def test_time_condition_last_week
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2022, 10, 23).beginning_of_day.to_hb_iso8601,
      Time.new(2022, 10, 30).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("先週")
  end

  def test_time_condition_this_month
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2022, 11, 1).beginning_of_day.to_hb_iso8601,
      Time.new(2022, 12, 1).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("今月")
  end

  def test_time_condition_last_month
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2022, 10, 1).beginning_of_day.to_hb_iso8601,
      Time.new(2022, 11, 1).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("先月")
    assert_equal expected, @hb._time_search_value_of("前月")
  end

  def test_time_condition_this_year
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2022, 1, 1).beginning_of_day.to_hb_iso8601,
      Time.new(2023, 1, 1).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("今年")
  end

  def test_time_condition_last_year
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2021, 1, 1).beginning_of_day.to_hb_iso8601,
      Time.new(2022, 1, 1).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("去年")
  end

  def test_time_condition_year_before_last_year
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2020, 1, 1).beginning_of_day.to_hb_iso8601,
      Time.new(2021, 1, 1).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("一昨年")
  end

  def test_time_condition_2_3_to_4_5
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2022, 2, 3).beginning_of_day.to_hb_iso8601,
      Time.new(2022, 4, 5).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("2/3 - 4/5")
  end

  def test_time_condition_12_1_to_1_4
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2022, 12, 1).beginning_of_day.to_hb_iso8601,
      Time.new(2023, 1, 5).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("12 / 1 - 1 / 5")
  end

  def test_time_condition_2021_12_1_to_2021_1_4
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2021, 12, 1).beginning_of_day.to_hb_iso8601,
      Time.new(2022, 1, 5).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("2021 / 12 / 1 - 2022 / 1 / 5")
  end

  def test_time_condition_2021_12_1_to_1_4
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2021, 12, 1).beginning_of_day.to_hb_iso8601,
      Time.new(2022, 1, 5).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("2021 / 12 / 1 - 1 / 5")
  end

  def test_time_condition_8_month
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2022, 8, 1).beginning_of_day.to_hb_iso8601,
      Time.new(2022, 9, 1).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("8月")
  end

  def test_time_condition_12_month
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2021, 12, 1).beginning_of_day.to_hb_iso8601,
      Time.new(2022, 1, 1).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("12月")
  end

  def test_time_condition_7_days
    Time.stubs(:now).returns(Time.local(2022,11,4))
    expected = [
      Time.new(2022, 10, 29).beginning_of_day.to_hb_iso8601,
      Time.new(2022, 11, 5).beginning_of_day.to_hb_iso8601
    ]
    assert_equal expected, @hb._time_search_value_of("7日")
  end


=begin
  def test_clean
    assert_equal [], @hb.clean
  end
=end

end
