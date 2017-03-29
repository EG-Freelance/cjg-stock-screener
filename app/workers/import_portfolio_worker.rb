# Worker for importing portfolio
class ImportPortfolioWorker
  include Sidekiq::Worker
  include ApplicationHelper
  sidekiq_options queue: 'high', unique: :until_executed
  
  def perform(data_set_id)
    
    set = DataSet.find(data_set_id)
  	
  	last_row = set.row_data.map { |rd| rd.row_number }.max
  	
    spreadsheet = set.row_data.sort_by { |rd| rd.row_number }.map { |rd| eval(rd.data) }
    
    # header is in first row
    header = spreadsheet[0].collect(&:strip)
    
    # set common timestamp for all entries
    set_created_at = DateTime.now
    
    # loop through all items
    (1..(last_row - 1)).each do |i|
      
      # pairing up header column with data
      row = Hash[[header, spreadsheet[i]].transpose]
      
      # position_data: 0. full text; 1. symbol; 2. option expiration; 3. option strike; 4. call/put
      position_data = row["Symbol"].match(/^(\S+)(?:\s([A-Z][a-z]{2}\s\d{2}\s\'\d{2})\s\$([\d\.]+)\s((?:Call|Put)))?/)
      
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
      if row["Exchange"] == "NSDQ"
        exchange = "NASD"
      elsif (row["Exchange"] == "CINC" || row["Exchange"] == "OTC" ) && !Stock.where(symbol: sym).empty?
        exchange = Stock.find_by(symbol: sym).exchange
      else
        exchange = row["Exchange"]
      end
      market_cap_data = row["Market Cap"].to_s.match(/([\d\,\.]+)((?:M|B))/)
      market_cap_data = "0" if market_cap_data.nil?
      market_cap = market_cap_data[1].to_f * (market_cap_data[2] == "B" ? 1000000000 : 1000000)
      pi_description = row["Description"]
      position = row["Long or Short"].downcase
      date_acq = row["Date Added"]
      quantity = row["Quantity"].abs
      paid = row["Price Paid $"].to_f
      last = row["Last Price $"].to_f
      change = row["Change %"].to_f
      day_gain_p = row["Day's Gain %"].to_f
      day_gain = row["Day's Gain $"].to_f
      tot_gain_p = row["Total Gain %"].to_f
      tot_gain = row["Total Gain $"].to_f
      market_val = row["Value $"].to_f
      
      # create/update security
      stock = Stock.where(
        symbol: sym
      ).first_or_create
      unless market_cap == 0
        stock.update(
          exchange: exchange, 
          pi_description: pi_description, 
          market_cap: market_cap
        )
      end
      
      # create/update portfolio entry
      pi = PortfolioItem.where(
        stock_id: stock.id, 
        position: position, 
        pos_type: pos_type, 
        op_type: op_type, 
        op_strike: op_strike, 
        op_expiration: op_expiration,
        date_acq: date_acq 
      ).first_or_create
      pi.update(
        quantity: quantity, 
        paid: paid, 
        last: last, 
        change: change, 
        day_gain: day_gain, 
        day_gain_p: day_gain_p, 
        tot_gain: tot_gain, 
        tot_gain_p: tot_gain_p, 
        market_val: market_val,
        set_created_at: set_created_at
      )
    end
    # Destroy PortfolioItems that are no longer active to avoid carrying closed positions
    PortfolioItem.where.not(set_created_at: set_created_at).destroy_all
    RowDatum.destroy_all
    DataSet.destroy_all
    GetScreenMechanizeWorker.perform_async
  end
  
  #########################
  # Import for old format #
  #########################
  
  # def perform(data_set_id)
    
  #   set = DataSet.find(data_set_id)
  	
  # 	last_row = set.row_data.map { |rd| rd.row_number }.max
  	
  #   spreadsheet = set.row_data.sort_by { |rd| rd.row_number }.map { |rd| eval(rd.data) }
    
  #   # header is in first row
  #   header = spreadsheet[0]
    
  #   # set common timestamp for all entries
  #   set_created_at = DateTime.now
    
  #   # loop through all items
  #   (1..(last_row - 1)).each do |i|
      
  #     # pairing up header column with data
  #     row = Hash[[header, spreadsheet[i]].transpose]
      
  #     # position_data: 0. full text; 1. symbol; 2. option expiration; 3. option strike; 4. call/put
  #     position_data = row[" Symbol"].match(/^(\S+)(?:\s([A-Z][a-z]{2}\s\d{2}\s\'\d{2})\s\$([\d\.]+)\s((?:Call|Put)))?/)
      
  #     # classify as stock or option
  #     if position_data[2].nil? && position_data[3].nil? && position_data[4].nil?
  #       pos_type = "stock"
  #       op_type = nil
  #       op_strike = nil
  #       op_expiration = nil
  #     else
  #       pos_type = "option"
  #       op_type = position_data[4]
  #       op_strike = position_data[3]
  #       op_expiration = position_data[2]
  #     end
      
  #     # save remaining data
  #     sym = position_data[1]
  #     pi_description = row["Description"]
  #     if row["Exchange"] == "NSDQ"
  #       exchange = "NASD"
  #     elsif (row["Exchange"] == "CINC" || row["Exchange"] == "OTC" ) && !Stock.where(symbol: sym).empty?
  #       exchange = Stock.find_by(symbol: sym).exchange
  #     else
  #       exchange = row["Exchange"]
  #     end
  #     market_cap_data = row["Market Cap"].match(/([\d\,\.]+)((?:M|B))/)
  #     market_cap = market_cap_data[1].to_f * (market_cap_data[2] == "B" ? 1000000000 : 1000000)
  #     pi_description = row["Description"]
  #     position = row["Long or Short"].downcase
  #     date_acq_string = row["Date Acquired"].class == String ? row["Date Acquired"] : row["Date Acquired"].strftime("%m/%d/%y")
  #     date_acq_data = date_acq_string.match(/(Last\s)?(\d{1,2})\/(\d{1,2})\/(\d{2,4})/)
  #     if date_acq_data[1].nil?
  #       date_acq = DateTime.new(date_acq_data[4].to_i, date_acq_data[2].to_i, date_acq_data[3].to_i)
  #     else
  #       date_acq = DateTime.new(("20"+date_acq_data[4]).to_i, date_acq_data[2].to_i, date_acq_data[3].to_i)
  #     end
  #     quantity = row["Quantity"].abs
  #     paid = row["Price Paid"].to_f
  #     last = row["Last Trade"].to_f
  #     change = row["Change %"].to_f
  #     day_gain_p = row["Day's Gain %"].to_f
  #     day_gain = row["Day's Gain $"].to_f
  #     tot_gain_p = row["Total Gain %"].to_f
  #     tot_gain = row["Total Gain $"].to_f
  #     market_val = row["Market Value"].to_f
      
  #     # create/update security
  #     stock = Stock.where(
  #       symbol: sym
  #     ).first_or_create
  #     unless market_cap == 0
  #       stock.update(
  #         exchange: exchange, 
  #         pi_description: pi_description, 
  #         market_cap: market_cap
  #       )
  #     end
      
  #     # create/update portfolio entry
  #     pi = PortfolioItem.where(
  #       stock_id: stock.id, 
  #       position: position, 
  #       pos_type: pos_type, 
  #       op_type: op_type, 
  #       op_strike: op_strike, 
  #       op_expiration: op_expiration,
  #       date_acq: date_acq 
  #     ).first_or_create
  #     pi.update(
  #       quantity: quantity, 
  #       paid: paid, 
  #       last: last, 
  #       change: change, 
  #       day_gain: day_gain, 
  #       day_gain_p: day_gain_p, 
  #       tot_gain: tot_gain, 
  #       tot_gain_p: tot_gain_p, 
  #       market_val: market_val,
  #       set_created_at: set_created_at
  #     )
  #   end
  #   # Destroy PortfolioItems that are no longer active to avoid carrying closed positions
  #   PortfolioItem.where.not(set_created_at: set_created_at).destroy_all
  #   RowDatum.destroy_all
  #   DataSet.destroy_all
  #   GetScreenMechanizeWorker.perform_async
  # end
end