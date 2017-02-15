desc "Update Earnings Dates"
task :update_earnings_dates => :environment do
  puts "Spawning workers to update earnings dates..."
	stocks = Stock.all
	# spawn workers for all stocks whose earnings dates have passed
	stocks.each { |t| UpdateEarningsDatesWorker.perform_async(s.id) unless s.earnings_dates.last.date > Date.today }
  puts "Done spawning workers."
end
