# Worker for getting screen CSV
class UpdateEarningsDatesWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'high'
  
  def perform(date)
    stocks = Stock.all.includes(:earnings_dates)
    # get next earnings_date by date of announcement
    agent = Mechanize.new
    # set beginning date to two weeks earlier if first run
  
    date_string = date.strftime("%Y%m%d")
    
    begin
      response = agent.get("https://biz.yahoo.com/research/earncal/#{date_string}.html")
    rescue
      puts "No earnings or date error for #{date}"
      break
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
  end
  
  # def perform(id)
  # 	stock = Stock.find(id)
  # 	stock.get_next_earnings_date
  # end
end