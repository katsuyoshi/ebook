require 'json'
require 'date'

class Slip

  attr_reader :text
  attr_accessor :deal_kind, :customer, :total

  def initialize text
    @text = text
  end

  def deal_kind
    @deal_kind || candidate_deal_kind
  end

  def deal_at
    @deal_at || candidate_deal_at
  end

  def deal_at= time
    case time
    when '今日', /today/i
      @deal_at = Date.today.to_time
    when '昨日', /yesterday/i
      @deal_at = Date.today.to_time - 24 * 60 * 60
    when '一昨日', /day before yesterday/i
      @deal_at = Date.today.to_time - 2 * 24 * 60 * 60
    when String
      if /月/
        unless /年/ =~ time
          time = "#{Time.now.year}年" + time
        end
        @deal_at = Date.strptime(time, "%Y年%m月%d日").to_time
      else
        @deal_at = Date.parse(time).to_time
      end
    else
      @deal_at = time.to_time
    end
  end

  def customer
    @customer || candidate_customers.first
  end

  def total
    @total || candidate_total
  end


  def candidate_deal_at
    text.scan(/((\d{4})年)?(\d{1,2})月(\d{1,2})日|((\d{4})\/)?(\d{1,2})\/(\d{1,2})/)
      .map{|a| Time.new((a[1]||a[9]||Time.now.year.to_s).to_i, (a[2]||a[10]).to_i, (a[3]||a[11]).to_i)}.sort.first
  end

  def candidate_deal_kind
    %w(見積 注文 請求 納品 領収).map do |k|
      [
        k,
        text.scan(/#{k}/).size
      ]
    end.sort{|a,b| b.last <=> a.last}
    .first.first + "書"
  end

  def candidate_customers
    text.lines.select do |k|
      unless /(^(\||=|\-|\+)+$)|(見積|注文|請求|納品|領収|アイテム|支払|トピック|検索|住所|更新|数量|価格|割引|計|年|月|日)|([0-9a-f]{8}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{12})|^¥?([\d,.]+)円?$/ =~ k
        true
      else
        false
      end
    end[0,3].map{|e| e.chomp}
  end

  def candidate_total
    if /合計.*?¥?([\d,.]+)円?/ =~ text
      $1
    else
      nil
    end
  end

end

if $0 == __FILE__
  s = Slip.new JSON.parse(File.read("annotations.json"))['responses'].first['textAnnotations'].first['description']
  p s.candidate_deal_kind
  p s.candidate_total
  p s.candidate_deal_at
  p s.candidate_customers
  slip = s
  p "書類: #{slip.candidate_deal_kind}\n取引日: #{slip.candidate_deal_at.strftime('%m月%d日')}\n相手先: #{slip.candidate_customers.first}\n金額: #{slip.candidate_total}\nで登録しますか？", ["はい", "いいえ"]

  s.deal_at = "今日"; p s.deal_at
  s.deal_at = "今日"; p [s.deal_at, s.deal_at == Date.today.to_time]
  s.deal_at = "昨日"; p [s.deal_at, s.deal_at == Date.today.to_time - 24 * 60 * 60]
  s.deal_at = "一昨日"; p [s.deal_at, s.deal_at == Date.today.to_time - 2 * 24 * 60 * 60]
  s.deal_at = "2022年11月2日"; p s.deal_at
  s.deal_at = "11月2日"; p s.deal_at
end

