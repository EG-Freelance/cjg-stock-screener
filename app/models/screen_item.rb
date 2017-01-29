class ScreenItem < ActiveRecord::Base
  include MathStuff
  
  belongs_to :stock, :dependent => :destroy
  
  
  def self.get_data(results)
    data_set = DataSet.create()
    
    header = results[0]
    RowDatum.create(data_set_id: data_set.id, data: header.to_s, row_number: 1, data_type: "screen")
    results[1..-1].each_with_index do |row, i|
      RowDatum.create(data_set_id: data_set.id, data: row.to_s, row_number: i + 2, data_type: "screen")
    end
    
    ImportScreenMechanizeWorker.perform_async(data_set.id)

  end
  
  def self.import(file)
    data_set = DataSet.create()
    
    # import microsoft excel file
    spreadsheet = open_spreadsheet(file)
    
    # header is in first row
    header = spreadsheet.row(1)
    RowDatum.create(data_set_id: data_set.id, data: header.to_s, row_number: 1, data_type: "screen")
    (2..spreadsheet.last_row).each do |i|
      RowDatum.create(data_set_id: data_set.id, data: spreadsheet.row(i).to_s, row_number: i, data_type: "screen")
    end
    
    ImportScreenWorker.perform_async(data_set.id)
  end
  
  def self.auto_import(auto_data)
    data_set = DataSet.create()
    
    header = auto_data[0]
    RowDatum.create(data_set_id: data_set.id, data: header.to_s, row_number: 1, data_type: "screen")
    auto_data[1..-1].each_with_index do |row, i|
      RowDatum.create(data_set_id: data_set.id, data: row.to_s, row_number: i + 2, data_type: "screen")
    end
    
    ImportScreenWorker.perform_async(data_set.id)
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
