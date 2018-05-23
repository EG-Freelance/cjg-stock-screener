# Worker for getting screen CSV
class OhlcWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'high', unique: :until_executed
  
  def perform(s_array, email)
    # set agent
    agent = Mechanize.new
    
    # remove unnecessary header 
    s_array = s_array[1..-1]
    
    # separate rows with populated data [ [empty_data], [populated_data] ]
    part = s_array.partition { |s| s[2].nil? }
    
    # get unique stock symbols (except where data are already provided)
    uniq_sym = part[0].map { |s| s[0] }.uniq
    
    # create OHLC data container
    ohlc_hash = {}
    
    # populate data
    uniq_sym.each do |s|
      response = agent.get("https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=#{s}&apikey=#{ENV['AA_KEY']}")
      ohlc_hash[s] = JSON.parse(response.body)
    end

    # create output workbook
    output = Spreadsheet::Workbook.new
    
    # name tab
    page = output.create_worksheet :name => "OHLC Log"

    # set header format
    header_format = Spreadsheet::Format.new :weight => :bold, :border => :thin, :horizontal_align => :center, :pattern_fg_color => :lime, :pattern => 1, :size => 9, :text_wrap => true, :vertical_align => :top

    # set headers
    page.row(0).push "Symbol", "Date", "Open", "High", "Low", "Close"
    6.times do |i|
      page.row(0).set_format(i, header_format)
    end
    
    # populate output spreadsheet
    s_array.each_with_index do |s,i|
      if s[2].nil?
        page.row(i+1).push s[0], s[1], ohlc_hash[s[0]]['Time Series (Daily)'][s[1]]['1. open'], ohlc_hash[s[0]]['Time Series (Daily)'][s[1]]['2. high'], ohlc_hash[s[0]]['Time Series (Daily)'][s[1]]['3. low'], ohlc_hash[s[0]]['Time Series (Daily)'][s[1]]['4. close']
      else
        page.row(i+1).push s[0], s[1], s[2], s[3], s[4], s[5]
      end
    end
    
    output.write ('temp_ohlc.xls')
    UpdateMailer.ohlc_email(email).deliver_now
  end
end