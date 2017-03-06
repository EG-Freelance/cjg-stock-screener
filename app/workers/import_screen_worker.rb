# Worker for importing screen
class ImportScreenWorker
  include Sidekiq::Worker
  include ApplicationHelper
  sidekiq_options queue: 'high'
  
  def perform(data_set_id)
  	set = DataSet.find(data_set_id)
  	
  	last_row = set.row_data.map { |rd| rd.row_number }.max
  	
    spreadsheet = set.row_data.sort_by { |rd| rd.row_number }.map { |rd| eval(rd.data) }
    
    # header is in first row
    header = spreadsheet[0]
    
    # set common timestamp for all entries
    set_created_at = DateTime.now
    
    # use array to set adj_invest_to_assets to limit DB calls
    si_array = []
    
    # data start in 2nd row (with 0-index array)
    (1..(last_row - 1)).each do |i|
      
      # pairing up header column with data
      row = Hash[[header, spreadsheet[i]].transpose]
      
      # position_data: 0. full text; 1. exchange
      position_data = row["Symbol"].match(/(.+)\:(.+)/)
      sym = position_data[2]
      exchange = position_data[1]
      market_cap = row["Market capitalization"]
      si_description = row["Company Name"]
      lm_revenue = row["Revenue-Last Month"]

      # SI params
      net_stock_issues = row["NetStockIssues"].to_d
      rel_accruals = row["RelAccruals"].to_d
      net_op_assets_scaled = row["NetOpAssets Scaled"].to_d
      assets_growth = row["Assets Growth"].to_d
      invest_to_assets = row["InvestToAssets"] == "n/a" ? nil : row["InvestToAssets"].to_d  
      adj_invest_to_assets = invest_to_assets
      l_52_wk_price = row["Price-52 week price percent change"].to_d
      profit_prem = row["Gross Profit Premium"].to_d
      roa_q = row["ROA Quarterly"].to_d
      dist_total_2 = row["DistTotal2"].to_i
      
      # create/update security
      stock = Stock.where(
        exchange: exchange, 
        symbol: sym
      ).first_or_create
      stock.update(
        si_description: si_description, 
        market_cap: market_cap,
        lm_revenue: lm_revenue
      )
      
      # create/update portfolio entry
      si = ScreenItem.where(
      	stock_id: stock.id,
      	net_stock_issues: net_stock_issues,
	      rel_accruals: rel_accruals,
	      net_op_assets_scaled: net_op_assets_scaled,
	      assets_growth: assets_growth,
	      invest_to_assets: invest_to_assets,
	      adj_invest_to_assets: adj_invest_to_assets,
	      l_52_wk_price: l_52_wk_price,
	      profit_prem: profit_prem,
	      roa_q: roa_q,
	      dist_total_2: dist_total_2,
        set_created_at: set_created_at
      ).first_or_create
      si_array << si
    end
    # set adj_invest_to_assets
    invest_to_assets_array = si_array.map { |si| si.invest_to_assets }.compact
    med_ita = MathStuff.median(invest_to_assets_array)
    si_array.each { |si| si.update(adj_invest_to_assets: med_ita) if si.invest_to_assets.nil? }
    
    # remove all previous screen items (trying to stay below 10k DB entries)
    ScreenItem.where('set_created_at < ?', set_created_at).destroy_all
  end
end