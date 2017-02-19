class Stock < ActiveRecord::Base
  has_many :earnings_dates
  
  def get_next_earnings_date
    # get next earnings_date by stock symbol
    agent = Mechanize.new
    begin
      # get to yahoo earnings page
      response = agent.get("https://biz.yahoo.com/research/earncal/#{self.symbol[0]}/#{self.symbol}.html")
    rescue
      # exit if the page cannot load
      puts "Error 404 (symbol not found on Yahoo?)"
      return false
    end
    
    # get the date from the first bold header
    date_text = response.css('b').first.text
    # parse raw header data into date
    date = date_text.match(/\n([A-Z][a-z]{2,8}\s\d{1,2}\,\s\d{4})/)[1]
    
    # create new earnings date
    self.earnings_dates.where(date: date.to_date).first_or_create
    
    # delete unneeded old earnings dates (all except most recent and upcoming) to maintain DB size
    if self.earnings_dates.count >= 3
      self.earnings_dates[0..-3].destroy_all
    end
  end
  
  def self.get_earnings_by_date
    stocks = Stock.all.includes(:earnings_dates)
    # get next earnings_date by date of announcement
    agent = Mechanize.new
    # set beginning date to two weeks earlier if first run
    b_date = Date.today
    e_date = Date.today + 2.weeks
    # set range to extend two weeks into future
    date_range = b_date..e_date
    date_range.each do |date|
      date_string = date.strftime("%Y%m%d")
      
      begin
        response = agent.get("https://biz.yahoo.com/research/earncal/#{date_string}.html")
      rescue
        puts "No earnings or date error for #{date}"
        next
      end
      
      # table varies in what column it uses to display time, so check for time index
      t_el = response.search('table').find { |table| table.at('tr').at('td').text.match(/\A\n\sEarnings/) }.search('tr')[2].search('td').find { |td| td.text == "Time" }
      t_index = symbol_array = response.search('table').find { |table| table.at('tr').at('td').text.match(/\A\n\sEarnings/) }.search('tr')[2].search('td').index(t_el)
      
      # symbol_array: ["symbol", "earnings_date_time"]
      symbol_array = response.search('table').find { |table| table.at('tr').at('td').text.match(/\A\n\sEarnings/) }.search('tr')[3..-3].map { |tr| [tr.search('td')[1].text, tr.search('td')[t_index].text] }  
      symbol_array.each do |sym|
        # remove any possible period suffixes from stocks, but skip entries without symbols
        begin
          s = sym[0].match(/([A-Z\d]+)(?:\.)?/)[1]
          # skip entries from other stock exchanges for now
          next if sym[0].match(/\./)
        rescue
          puts "No valid entry for #{sym}"
          next
        end
        # select the stock in the system if it exists
        stock = stocks.find_by(symbol: s)
        if stock.nil?
          # if it doesn't exist, move to the next entry
          next
        else
          # if it does, save the current date as an entry with the provided time
          stock.earnings_dates.where(date: date, time: sym[1]).first_or_create   
          
          # delete unneeded old earnings dates (all except most recent and upcoming) to maintain DB size
          if stock.earnings_dates.count >= 3
            stock.earnings_dates[0..-3].each { |e| e.destroy }
          end
        end
      end # end symbol array
    end # end date array
     
    
  end
  
end
