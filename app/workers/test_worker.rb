# Test phantomjs setup
class TestWorker
  include Sidekiq::Worker
  include ApplicationHelper
  sidekiq_options queue: 'high'
  
  def perform
	  # Attempt to get worker to access 
	  
	  driver = Selenium::WebDriver.for :remote, url: 'http://localhost:8001'
	  driver.navigate.to 'https://stock.screener.co'
  end
end