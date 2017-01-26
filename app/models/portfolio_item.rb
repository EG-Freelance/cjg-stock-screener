class PortfolioItem < ActiveRecord::Base
	belongs_to :stock, :dependent => :destroy
	
	def self.import(file)
    ImportPortfolioWorker.perform_async(file)
  end
	
  # def self.open_spreadsheet(file)
  #   case File.extname(file.original_filename)
  #     when ".csv" then Roo::Csv.new(file.path)
  #     when ".xls" then Roo::Excel.new(file.path)
  #     when ".xlsx" then Roo::Excelx.new(file.path)
  #   else raise "Unknown file type: #{file.original_filename}"
  #   end
  # end
end
