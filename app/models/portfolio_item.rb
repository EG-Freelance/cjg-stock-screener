class PortfolioItem < ActiveRecord::Base
	belongs_to :stock
	
	#########################
	# Import for new format #
	#########################
  def self.import_pi(file)
	  data_set = DataSet.create()
	  
	  spreadsheet = open_spreadsheet(file)
	  
	  # header is in 11th row
	  header = spreadsheet.row(7)
	  
	  last_row = spreadsheet.last_row
	  
	  # set marginable security amount
	  MarginableSecurity.first.update(amount: spreadsheet.row(3)[7])
	  
    RowDatum.create(data_set_id: data_set.id, data: header.to_s, row_number: 1, data_type: "portfolio")
	  # data start on 13th row and end 3 before last row (last row is cash summary)
    (8..(last_row)).each do |i|
      data = spreadsheet.row(i)
      # break when we come to the "CASH" row
      if data[0] == "CASH" && data[1].nil?
        RowDatum.create(data_set_id: data_set.id, data: data.compact.to_s, row_number: i - 6)
        break
      end
      data[1] = data[1].to_s.strip
      data[2] = data[2].to_s.strip
      # data[3] == 1 || data[3].try(:downcase) == "long" ? data[3] = "long" : data[3] = "short"
      data[5] > 0 ? data[3] = "long" : data[3] = "short"
      data[4] = data[4].to_s.strip
      RowDatum.create(data_set_id: data_set.id, data: data.to_s, row_number: i - 6, data_type: "portfolio")
    end
    
    #RowDatum.create(data_set_id: data_set.id, data: spreadsheet.row(last_row - 4).compact.to_s, row_number: last_row - 10)
     
    ImportPortfolioWorker.perform_async(data_set.id)
  end
	
	#########################
	# Import for old format #
	#########################
	def self.import_old_pi(file)
	  data_set = DataSet.create()
	  
	  spreadsheet = open_spreadsheet(file)
	  
	  # header is in 11th row
	  header = spreadsheet.row(11)
	  
    RowDatum.create(data_set_id: data_set.id, data: header.to_s, row_number: 1, data_type: "portfolio")
	  # data start on 13th row and end 3 before last row (last row is cash summary)
    (13..(spreadsheet.last_row - 5)).each do |i|
      data = spreadsheet.row(i)
      data[4] = data[4].to_s.gsub(/(\d{4})\-(\d{2})\-(\d{2})/, '\2/\3/\1')
      RowDatum.create(data_set_id: data_set.id, data: data.to_s, row_number: i - 11, data_type: "portfolio")
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
