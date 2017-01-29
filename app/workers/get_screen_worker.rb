# Worker for getting screen CSV
class GetScreenWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'high'
  
  
  def perform
	  # phantomjs needs to be running in the background on port 8001
	  # phantomjs --webdriver=8001
	  
	  # set up selenium webdriver with phantomjs
	  driver = Selenium::WebDriver.for :phantomjs
	  driver.navigate.to 'https://stock.screener.co'
	  
	  # declare a wait process to find elements that require time to process
	  wait = Selenium::WebDriver::Wait.new(:timeout => 10)
	  
	  # set window size to make sure that all elements load
	  target_size = Selenium::WebDriver::Dimension.new(1920, 1080)
	  driver.manage.window.size = target_size
	  
	  # set login info
	  username = ENV['SSLOGIN']
	  password = ENV['SSPWD']
	  
	  # fill out login creds
	  user_field = wait.until { driver.find_element(:class, "gwt-TextBox") }.send_keys username
	  password_field = wait.until { driver.find_element(:class, 'gwt-PasswordTextBox') }.send_keys password
	  
	  # login
	  wait.until { driver.find_element(:class, 'gwt-PushButton') }.click
	  
	  # open advanced screens
	  el = wait.until { driver.find_element(:id, 'gwt-uid-18') }
	  el.click
	  el = wait.until { driver.find_element(:id, 'gwt-uid-19') }
	  el.click
	  
	  # select the New1 list item
	  el = wait.until { driver.find_elements(:class, 'AKQ5O4-c-e') }.find { |e| e.text == "New1" }
	  el = wait.until { driver.find_elements(:class, 'AKQ5O4-c-b') }.find { |e| e.text == "New1" } if el.nil?
	  
	  el.click
	  
	  # select Mispricing8
	  el = wait.until { driver.find_elements(:class, "AKQ5O4-c-b") }.find { |e| e.text == "Mispricing8\nDomestic - Price GTE 5 - Net Stock Issues - RelAccruals - NetOpAssets Scaled - Assets Growth - InvestToAssets - Momentum - Gross Profit Premium - ROA Quarterly - Mkt Cap" }
	  el = wait.until { driver.find_elements(:class, "AKQ5O4-c-e") }.find { |e| e.text == "Mispricing8\nDomestic - Price GTE 5 - Net Stock Issues - RelAccruals - NetOpAssets Scaled - Assets Growth - InvestToAssets - Momentum - Gross Profit Premium - ROA Quarterly - Mkt Cap" } if el.nil?
	  
	  el.click
	  
	  # load the screen
	  el = wait.until { driver.find_elements(:class, 'gwt-PushButton') }.find { |e| e.text == "Load Screen" }
	  el.click
	  sleep(1)
	  
	  # check the box to send results to screen window
	  el = wait.until { driver.find_element(:class, 'gwt-CheckBox') }.click
	  
	  # remove unnecessary columns and add necessary columns
	  puts 'removing columns...'
	  remove_cols = ["Exchange Country", "Price-200 Day Average", "Return on Assets Quarterly"]
	  remove_cols.each do |r|
			data_cols = wait.until { driver.find_elements(:class, 'masterview-grid-header-cell') }
	  	unless data_cols.find { |dc| dc.text == r }.nil?
	  		el = data_cols.find { |dc| dc.text == r }
	  		driver.action.context_click(el).perform
	  		context_items = wait.until { driver.find_elements(:class, 'contextItem') }
	  		rc = context_items.find { |ci| ci.text == "Remove Column" }
	  		rc.click
	  	end
	  end
	  
	  puts 'adding columns...'
	  add_cols = ["ROA Quarterly", "DistTotal2"]
	  add_cols.each do |a|
	  	puts a
			data_cols = wait.until { driver.find_elements(:class, 'masterview-grid-header-cell') }
	  	if data_cols.find { |e| e.text[a] }.nil?
	  		puts "working on #{a}"
		  	# open free form column module
		  	ff = wait.until { driver.find_element(:id, 'gwt-uid-36') }
		  	ff.click
		  	
		  	# input new column
		  	wait.until { driver.find_element(:class, 'gwt-SuggestBox') }.send_keys a
		  	# submit new column
		  	sc = wait.until { driver.find_elements(:class, 'gwt-PushButton') }.find { |e| e.text == "Save Column" }
		  	sc.click
		  	sleep(1)
		  end
	  end
	  
	  table = driver.find_elements(:class, 'masterview-grid').first
	  tds = table.find_element(:css, 'tr').find_elements(:css, 'td')
	  td = tds.last
	  
	  # compile data for CSV
	  csv_data_rows = []
	  csv_header = tds.map { |e| e.text.gsub(" \u25B2", "") }
	  
	  # find number of pages
	  rows_string = wait.until { driver.find_elements(:class, 'gwt-Label') }.find { |e| e.text[0..3] == "Rows" }.text
	  rows = rows_string.match(/Rows\s\d{1,5}\-\d{1,5} of (\d{1,5})/)[1].to_f
	  pages = (rows/50).ceil
	  
	  # first page
	  puts "saving page 1"
	  data_set = wait.until { driver.find_elements(:class, "AKQ5O4-a-y") }.first.find_elements(:css, 'tr').each do |row|
	  	data_array = wait.until { row.find_elements(:css, 'td') }.map { |td| td.text }
	  	csv_data_rows << data_array unless data_array.length < 2
	  end
	  
	  (pages - 1).times do |i|
	  	# next page
	  	puts "saving page #{i + 2}..."
	  	button = wait.until { driver.find_elements(:class, 'gwt-Button') }.find { |e| e.text == ">" }
	  	button.click
	  	sleep(1)
		  data_set = wait.until { driver.find_elements(:class, "AKQ5O4-a-y") }.first.find_elements(:css, 'tr').each do |row|
		  	data_array = wait.until { row.find_elements(:css, 'td') }.map { |td| td.text }
		  	csv_data_rows << data_array unless data_array.length < 2
		  end
	  end
	  
	  csv_data_rows.delete_if { |r| r[0] == " " }
	  
	  ImportScreenItem.auto_import(csv_data_rows)
	end
end