require 'json'
require 'date'

class Slip

  attr_reader :text

  def initialize text
    @text = text
  end

  def deal_kind
    @deal_kind || candidate_deal_kinds.first
  end

  def deal_kind= kind
    @deal_kind = kind
  end

  def deal_at
    @deal_at || candidate_deal_at.first
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

  def customer= customer
    @customer = customer
  end

  def total
    @total || candidate_total.first
  end

  def total= total
    @total = total
  end


  def candidate_deal_at
    begin
      a = text.scan(/((\d{4})年)?(\d{1,2})月(\d{1,2})日|((\d{4})\/)?(\d{1,2})\/(\d{1,2})|((\d{4})\-)?(\d{1,2})\-(\d{1,2})/)
      .map do |a|
        Time.new(
          (a[1]||a[5]||a[9]||Time.now.year.to_s).to_i,
          (a[2]||a[6]||a[10]).to_i,
          (a[3]||a[7]||a[11]).to_i
        ) rescue nil
      end
      
      a += text.scan(/(\d{1,2})\/(\d{1,2})(\/(\d{4}))?|(\d{1,2})\-(\d{1,2})(\-(\d{4}))?/).map do |a|
        Time.new(
          (a[3]||a[7]||Time.now.year.to_s).to_i,
          (a[0]||a[4]).to_i,
          (a[1]||a[5]).to_i
        )rescue nil
      end
      
      tomorrow = (Date.today + 1).to_time
      a.select{|e| e && e < tomorrow}.sort.uniq.reverse
    rescue
      nil
    end
  end

  def candidate_deal_kinds
    a = text.scan(/見積書|見積もり書|見積り書|注文書|請求書|納品書|領収書/)
    a.map do |e|
      case e
      when '見積もり書', '見積り書'
        '見積書'
      else
        e
      end
    end.uniq
  end

  def candidate_customers
    a = text.lines.select.with_index do |l,i|
      if i == 0
        nil
      else
        /(株式|有限|法人|合同|様|Inc|co[\,\.\']ltd|[\(（][株有合][\)）])/i =~ l
      end
    end
    a += text.lines.select.with_index do |k,i|
      if i == 0
        nil
      else
        unless /(^(\||=|\-|\+)+$)|(見積|注文|請求|納品|領収|アイテム|支払|トピック|検索|住所|更新|数量|価格|割引|計|年|月|日|、|。|@)|([0-9a-f]{8}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{12})|^¥?([\d,.]+)円?$/ =~ k
          true
        else
          false
        end
      end
    end

    ENV['OWN_COMPANY_NAMES'].split(':').each do |n|
      a.delete_if do |e|
        /#{n}/ =~ e
      end
    end
    a.map(&:chomp).map{|e| /(.+)様/ =~ e ? $1 : e}.uniq[0,5]
  end

  def candidate_total
    text.scan(/(¥?(\d+[\d\,\.]+)円?)/).select{|a| a.first =~ /[¥円]/}.map{|a| a[1].gsub(/\,/, '').to_i }.uniq.sort.reverse
  end

end

if $0 == __FILE__
  s = "株式会社いろは\n請求書\n123-456-7890\nno_reply@example.com\n123-4567\nxxxx\n1-2-34\n8: 123-4567\nxx県xx市xx町1-2-34\n株式会社にほへと\n部署名\n加納 尚子様\nB: 1/8/20\nプロジェクトタイトル: プロジェクト名\nプロジェクトの説明: 説明を記入\n注文番号: 12345\n請求書番号: 67890\n詳細\n項目1\n項目2\n項目3\n数量\n1\n税額\n55\n13\n25\n単価\n¥100.00\n¥90.00\n¥50.00\n小計\n合計\n10.00%\nお世話になっております。 プロジェクトでご一緒できて光栄です。\n次のご注文は30日以内に出荷されます。\n今後ともよろしくお願いします。\n永田次郎"
  s = Slip.new(s)
  s.deal_at
  exit


  s = Slip.new JSON.parse(File.read("annotations.json"))['responses'].first['textAnnotations'].first['description']
  p s.candidate_deal_kinds
  p s.candidate_total
  p s.candidate_deal_at
  p s.candidate_customers
  slip = s
  p "書類: #{slip.candidate_deal_kinds.first}\n取引日: #{slip.candidate_deal_at.strftime('%m月%d日')}\n相手先: #{slip.candidate_customers.first}\n金額: #{slip.candidate_total}\nで登録しますか？", ["はい", "いいえ"]

  s.deal_at = "今日"; p s.deal_at
  s.deal_at = "今日"; p [s.deal_at, s.deal_at == Date.today.to_time]
  s.deal_at = "昨日"; p [s.deal_at, s.deal_at == Date.today.to_time - 24 * 60 * 60]
  s.deal_at = "一昨日"; p [s.deal_at, s.deal_at == Date.today.to_time - 2 * 24 * 60 * 60]
  s.deal_at = "2022年11月2日"; p s.deal_at
  s.deal_at = "11月2日"; p s.deal_at
end

