class DisplayItem < ActiveRecord::Base
	has_one :stock
	has_many :portfolio_items, :through => :stock
	has_many :screen_items, :through => :stock
end