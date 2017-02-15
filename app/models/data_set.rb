class DataSet < ActiveRecord::Base
	has_many :row_data, dependent: :destroy
end
