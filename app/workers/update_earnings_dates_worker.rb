# Worker for getting screen CSV
class UpdateEarningsDatesWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'high'
  
  def perform(id)
  	stock = Stock.find(id)
  	stock.get_next_earnings_date
  end
end