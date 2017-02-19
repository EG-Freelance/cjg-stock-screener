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
    b_date = Date.today
    e_date = Date.today + 2.weeks
    # set range to extend two weeks into future
    date_range = b_date..e_date
    date_range.each do |date|
      UpdateEarningsDatesWorker.perform_async(date)
    end # end date array
     
    
  end
  
end
