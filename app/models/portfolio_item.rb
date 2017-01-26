class PortfolioItem < ActiveRecord::Base
	belongs_to :stock, :dependent => :destroy
	
	def self.import(file)
	  data_set = DataSet.create()
	  
	  spreadsheet = open_spreadsheet(file)
	  
	  # header is in 11th row
	  header = spreadsheet.row(11)
	  
    RowDatum.create(data_set_id: data_set.id, data: header.to_s, row_number: 1, data_type: "portfolio")
	  # data start on 13th row and end 3 before last row (last row is cash summary)
    (13..(spreadsheet.last_row - 3)).each do |i|
      RowDatum.create(data_set_id: data_set.id, data: spreadsheet.row(i).to_s, row_number: i-11, data_type: "portfolio")
    end
     
    ImportPortfolioWorker.perform_async(data_set.id)
  end
	
  def self.open_spreadsheet(file)
    case File.extname(file.original_filename)
      when ".csv" then Roo::Csv.new(file.path)
      when ".xls" then Roo::Excel.new(file.path)
      when ".xlsx" then Roo::Excelx.new(file.path)
    else raise "Unknown file type: #{file.original_filename}"
    end
  end
end
