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
    
    url = base + date_string

    begin
      response = agent.get(url)
      results = response.search('span').find { |s| s.text.match(/\d+\sresults/) }.text.match(/\d*\-\d*\sof\s(\d*)\sresults/)[1].to_i
    rescue
      puts "No earnings or date error for #{date}"
      return true
    end
    
    pages = (results/100.0).ceil
    
    pages.times do |i|
      if i == 0
        # financial calendar table
        table = response.at "#fin-cal-table"
        
        # rows of usable data
        rows = table.search('tr')[1..-1]
        
        # array of usable data arrays
        data = rows.map { |r| r.search('td').map { |c| c.text } }
      else
        paginated_url = url + "&offset=#{i * 100}&size=100"
        j = 0
        begin
          response = agent.get(paginated_url)
          # financial calendar table
          table = response.at "#fin-cal-table"
          
          # rows of usable data
          rows = table.search('tr')[1..-1]
          
          # array of usable data arrays
          data = rows.map { |r| r.search('td').map { |c| c.text } }
        rescue
          if j < 100
            puts "failed pagination attempt: page #{i}, attempt #{j}"
            j += 1
            retry
          else
            puts "failed 100 pagination attempts: page #{i}, attempt #{j}"
            return false
          end
        end
      end
      
      # financial calendar table
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
        stock.earnings_dates.where(date: date, time: d[2]).first_or_create   
        
        # delete unneeded old earnings dates (all except most recent and upcoming) to maintain DB size
        if stock.earnings_dates.count >= 3
          stock.earnings_dates[0..-3].each { |e| e.destroy }
        end
      end # end data
    end # end pages.times loop
  end # end process
end