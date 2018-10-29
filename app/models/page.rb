class Page < ActiveRecord::Base
	def self.wake_up_dyno
		agent = Mechanize.new
		agent.get('http://cjg-stock-screener.herokuapp.com')
		return true
	end
end
