# Worker for getting screen CSV
class UpdateEarningsDatesWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'high'
  
  def perform(date)
    # get Date object for date
    date = Date.parse(date)
    # eager load stocks and create symbol array and earnings date array
    stocks = Stock.all.includes(:earnings_dates)
    sym_array = stocks.map { |s| s.symbol }
    ed_array = stocks.map { |s| s.earnings_dates }.flatten
    ed_today_array = ed_array.select { |ed| ed.date == Date.today }
    
    # get next earnings_date by date of announcement
    agent = Mechanize.new
    # set beginning date to two weeks earlier if first run
    
    base = "http://finance.yahoo.com/calendar/earnings?day="
    
    date_string = date.strftime("%Y-%m-%d")

    begin
      response = agent.get(base + date_string)
    rescue
      puts "No earnings or date error for #{date}"
      return false
    end
    
    # financial calendar table
    table = response.at "#fin-cal-table"
    
    # rows of usable data
    rows = table.search('tr')[1..-1]
    
    # array of usable data arrays
    data = rows.map { |r| r.search('td').map { |c| c.text } }
    
    # don't use symbols with decimal points (foreign exchanges)
    data.delete_if { |d| d[0].match(/\./) }
    
    # remove data for stocks that aren't in the system
    data.delete_if { |d| !sym_array.include?(d[0]) }
    
    # remove earnings dates that no longer appear on this page
    ed_delete_array = ed_today_array.delete_if { |ed| data.map { |d| d[0] }.include?(ed.stock.symbol) }
    ed_delete_array.each { |ed| ed.destroy }
    
    data.each do |d|
      # select the stock in the system
      stock = stocks.find_by(symbol: d[0])
      # save the current date as an entry with the provided time
      stock.earnings_dates.where(date: date, time: d[5]).first_or_create   
      
      # delete unneeded old earnings dates (all except most recent and upcoming) to maintain DB size
      if stock.earnings_dates.count >= 3
        stock.earnings_dates[0..-3].each { |e| e.destroy }
      end
    end # end data
  end
end