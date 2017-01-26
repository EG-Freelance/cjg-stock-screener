desc "Import Portfolio Data"
task :import_portfolio => :environment do
  puts "Spawning worker to import portfolio data..."
		ImportPortfolioWorker.perform_async(file)
  puts "Done spawning worker."
end

desc "Import Screen Data"
task :refresh_rosters => :environment do
  puts "Spawning worker to import screen data..."
  	ImportScreenWorker.perform_async(file)
  puts "Done spawning worker."
end