class PortfolioItem < ActiveRecord::Base
	belongs_to :stock, :dependent => :destroy
	
	def self.import(file)
    # import microsoft excel file
    spreadsheet = open_spreadsheet(file)
    
    # header is in 11th row
    header = spreadsheet.row(11)
    
    # data start in 13th row
    (13..spreadsheet.last_row).each do |i|
      
      # pairing up header column with data
      row = Hash[[header, spreadsheet.row(i)].transpose]
      
      # position_data: 0. full text; 1. symbol; 2. option expiration; 3. option strike; 4. call/put
      position_data = row[" Symbol"].match(/^(\S+)(?:\s([A-Z][a-z]{2}\s\d{2}\s\'\d{2})\s\$([\d\.]+)\s((?:Call|Put)))?/)
      
      # classify as stock or option
      if position_data[2].nil? && position_data[3].nil? && position_data[4].nil?
        pos_type = "stock"
        op_type = nil
        op_strike = nil
        op_expiration = nil
      else
        pos_type = "option"
        op_type = position_data[4]
        op_strike = position_data[3]
        op_expiration = position_data[2]
      end
      
      # save remaining data
      sym = position_data[1]
      pi_description = row["Description"]
      exchange = row["Exchange"]
      market_cap_data = row["Market Cap"].match(/([\d\,\.]+)((?:M|B))/)
      market_cap = market_cap_data[1].to_f * (market_cap_data[2] == "B" ? 1000000000 : 1000000)
      pi_description = row["Description"]
      position = row["Long or Short"].downcase
      date_acq_data = row["Date Acquired"].match(/(Last\s)?(\d{1,2})\/(\d{1,2})\/(\d{2,4})/)
      if date_acq_data[1].nil?
        date_acq = DateTime.new(date_acq_data[4].to_i, date_acq_data[2].to_i, date_acq_data[3].to_i)
      else
        date_acq = DateTime.new(("20"+date_acq_data[4]).to_i, date_acq_data[2].to_i, date_acq_data[3].to_i)
      end
      quantity = row["Quantity"].abs
      paid = row["Price Paid"]
      last = row["Last Trade"]
      change = row["Change %"]
      day_gain_p = row["Day's Gain %"]
      day_gain = row["Day's Gain $"]
      tot_gain_p = row["Total Gain %"].to_f
      tot_gain = row["Total Gain $"].to_f
      market_val = row["Market Value"].to_f
      
      # create/update security
      stock = Stock.where(
        exchange: exchange, 
        symbol: sym
      ).first_or_create
      stock.update(
        pi_description: pi_description, 
        market_cap: market_cap
      )
      
      # create/update portfolio entry
      pi = PortfolioItem.where(
        stock_id: stock.id, 
        position: position, 
        pos_type: pos_type, 
        op_type: op_type, 
        op_strike: op_strike, 
        op_expiration: 
        op_expiration
      ).first_or_create
      pi.update(
        date_acq: date_acq, 
        quantity: quantity, 
        paid: paid, 
        last: last, 
        change: change, 
        day_gain: day_gain, 
        day_gain_p: day_gain_p, 
        tot_gain: tot_gain, 
        tot_gain_p: tot_gain_p, 
        market_val: market_val
      )
    end
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
