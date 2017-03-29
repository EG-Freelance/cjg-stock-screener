desc "Update Earnings Dates"
task :update_earnings_dates => :environment do
  puts "Spawning workers to update earnings dates..."
  Stock.get_earnings_by_date(false)
  puts "Done spawning workers."
end
