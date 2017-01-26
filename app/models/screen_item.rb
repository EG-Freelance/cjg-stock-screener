class ScreenItem < ActiveRecord::Base
	include MathStuff
	
	belongs_to :stock, :dependent => :destroy
	
	def self.import(file)
	  set = DataSet.create()
	  
	  # import microsoft excel file
    spreadsheet = open_spreadsheet(file)
    
    # header is in first row
    header = spreadsheet.row(1)
    RowDatum.create(set_id: set.id, data: header.to_s, row_number: 1, type: "screen")
    (2..spreadsheet.last_row).each do |i|
      RowDatum.create(set_id: set.id, data: spreadsheet.row(i).to_s, row_number: i, type: "screen")
    end
    
    ImportScreenWorker.perform_async(set.id)
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
