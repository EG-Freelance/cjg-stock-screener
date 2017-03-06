# Worker for setting display items for analysis page
class SetDisplayItemsWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'high', unique: :until_executed
  
  def perform
    # clear out current DisplayItem set
    DisplayItem.destroy_all
    
    disp_set_created_at = DateTime.now
    portfolio_items = PortfolioItem.all.includes(:stock, :stock => :earnings_dates)
    screen_items = ScreenItem.all.includes(:stock, :stock => :earnings_dates)
    
    # portfolio items
    pi_set_date_array = portfolio_items.pluck(:set_created_at).uniq.sort
    pi_period = pi_set_date_array.last
    pi_pool = portfolio_items.where(set_created_at: pi_period)
    
    # array of portfolio symbols
    portfolio_securities = pi_pool.pluck(:'stocks.symbol')
    
    # screen item variables and arrays
    si_set_date_array = screen_items.pluck(:set_created_at).uniq.sort
    si_period = si_set_date_array.last
    si_pool = screen_items.where(set_created_at: si_period)
    
    # set cap_separator
    separator = MathStuff.median(si_pool.pluck(:'stocks.market_cap'))
    cap_diff_array = si_pool.partition { |si| si.stock.market_cap >= separator }
    si_pool_lg = cap_diff_array[0]
    si_pool_sm = cap_diff_array[1]
    
    ##########################
    # Get large cap listings #
    ##########################
    
    count_lg = si_pool_lg.count
    # 0. net_stock_issues, 1. rel_accruals, 2. net_op_assets_scaled, 3. assets_growth, 4. invest_to_assets, 5. adj_invest_to_assets, 6. l_52_wk_price, 7. profit_prem, 8. roa_q, 9. dist_total_2
    param_array = si_pool_lg.map { |si| [si.net_stock_issues, si.rel_accruals, si.net_op_assets_scaled, si.assets_growth, si.invest_to_assets, si.adj_invest_to_assets, si.l_52_wk_price, si.profit_prem, si.roa_q, si.dist_total_2] }
    
    # transpose to get arrays of each separate category
    net_stock_issues_array, rel_accruals_array, net_op_assets_scaled_array, assets_growth_array, invest_to_assets_array, adj_invest_to_assets_array, l_52_wk_price_array, profit_prem_array, roa_q_array, dist_total_2_array = param_array.transpose
    
    # sort each category array
    net_stock_issues_array = net_stock_issues_array.sort
    rel_accruals_array = rel_accruals_array.sort
    net_op_assets_scaled_array = net_op_assets_scaled_array.sort
    assets_growth_array = assets_growth_array.sort
    #invest_to_assets_array = invest_to_assets_array.sort  # Can't sort nil
    adj_invest_to_assets_array = adj_invest_to_assets_array.sort
    l_52_wk_price_array = l_52_wk_price_array.sort
    profit_prem_array = profit_prem_array.sort
    roa_q_array = roa_q_array.sort
    dist_total_2_array = dist_total_2_array.sort
    
    si_lg = []
    si_lg_import = []
    #process data
    si_pool_lg.each do |si|
      # set net_stock_issues rank
      # count net_stock_issues below 1
      disc_nsi = net_stock_issues_array.count { |nsi| nsi < 1 }
      nsi_rank_raw = net_stock_issues_array.index(si.net_stock_issues) + 1 - disc_nsi
      nsi_rank = si.net_stock_issues < 1 ? 1 : (nsi_rank_raw / ((count_lg - disc_nsi) / 9.0)).ceil + 1
      # set rel_accruals_rank
      ra_rank_raw = rel_accruals_array.index(si.rel_accruals) + 1
      ra_rank = (ra_rank_raw / (count_lg / 10.0)).ceil
      # set net_op_assets_scaled_rank
      noas_rank_raw = net_op_assets_scaled_array.index(si.net_op_assets_scaled) + 1
      noas_rank = (noas_rank_raw / (count_lg / 10.0)).ceil
      # set assets_growth_rank
      ag_rank_raw = assets_growth_array.index(si.assets_growth) + 1
      ag_rank = (ag_rank_raw / (count_lg / 10.0)).ceil
      # set adj_invest_to_assets_rank
      aita_rank_raw = adj_invest_to_assets_array.index(si.adj_invest_to_assets) + 1
      aita_rank = (aita_rank_raw / (count_lg / 10.0)).ceil ##### Revisit
      # set l_52_wk_price_rank (reverse array for inverse point system)
      l52wp_rank_raw = l_52_wk_price_array.reverse.index(si.l_52_wk_price) + 1
      l52wp_rank = (l52wp_rank_raw / (count_lg / 10.0)).ceil
      # set profit_prem_rank (reverse array for inverse point system)
      pp_rank_raw = profit_prem_array.reverse.index(si.profit_prem) + 1
      pp_rank = (pp_rank_raw / (count_lg / 10.0)).ceil
      # set roa_q_rank (reverse array for inverse point system)
      rq_rank_raw = roa_q_array.reverse.index(si.roa_q) + 1
      rq_rank = (rq_rank_raw / (count_lg / 10.0)).ceil
      # set dist_total_2_rank
      dt2_rank_raw = dist_total_2_array.index(si.dist_total_2) + 1
      dt2_rank = (dt2_rank_raw / (count_lg / 10.0)).ceil
      # set next and prev earnings dates
      prev_ed = si.stock.earnings_dates.where('date < ?', Date.today)
      next_ed = si.stock.earnings_dates.where('date >= ?', Date.today)
      
      total_score = [nsi_rank, ra_rank, noas_rank, ag_rank, aita_rank, l52wp_rank, pp_rank, rq_rank, dt2_rank].sum
      
      # 0. symbol, 1. exchange, 2. company, 3. in pf, 4. rec action, 5. action, 6. total score, 7. total score pct, 8. Dist >7/8, 9. Mkt Cap, 10. NSI, 11. RA, 12. NOAS, 13. AG, 14. AITA, 15. L52WP, 16. PP, 17. RQ, 18. DT2, 19. Previous Earnings, 20. Next Earnings, 21. LM Rev
      si_lg << [
        si.stock.symbol, 
        si.stock.exchange,
        si.stock.si_description,
        portfolio_securities.include?(si.stock.symbol) ? "Yes" : "No",
        "ph", #rec action
        "placeholder", #action
        total_score,
        nil, #total score percentile (move down)
        nil, #Dist top10% > 7 or bottom10% > 8 (move down)
        si.stock.market_cap,
        nsi_rank,
        ra_rank,
        noas_rank,
        ag_rank,
        aita_rank,
        l52wp_rank,
        pp_rank,
        rq_rank,
        dt2_rank,
        prev_ed.empty? ? "N/A" : (Date.today - prev_ed.last.date).to_i,
        next_ed.empty? ? "N/A" : (next_ed.last.date - Date.today).to_i == 0 ? 0.1 : (next_ed.last.date - Date.today).to_i,
        si.stock.lm_revenue
      ]
    end
    # calculate programmatic action (si[4]), total score percentile (si[7]) and dist > 7 or 8 (si[8]) after initial setup
    ts_array = si_lg.map { |si| si[6] }.sort
    si_lg.each do |si| 
      si[7] = 1 - ((ts_array.index(si[6]) + 1)/ts_array.length.to_f)
      # set dist
      if si[7] >= 0.9
        si[8] = si[18] > 7 ? "Yes" : "No"
      elsif si[7] <= 0.1
        # set dist
        si[8] = si[18] > 8 ? "Yes" : "No"
      else
        si[8] = "N/A"
      end
      
      # set programmatic actions
      if si[3] == "Yes"
        if si[7] >= 0.9
          if si[18] <= 7
            # Yes, Top 10%, <=7
            si[4] = "Hold or add"
          else
            # Yes, Top 10%, >7
            si[4] = "Hold or sell"
          end
        elsif si[7] <= 0.1
          # Yes, Bottom 10%, Any Dist
          si[4] = "Sell"
        else
          # Yes, Middle 80%, Any Dist
          si[4] = "Close"
        end
      else
        if si[7] >= 0.9
          if si[18] <= 7
            # No, Top 10%, <=7
            si[4] = "No action"
          else
            # No, Top 10%, >7
            si[4] = "No action"
          end
        elsif si[7] <= 0.1
          if si[18] <= 8
            # No, Bottom 10%, <=8
            si[4] = "Short and put"
          else
            # No, Bottom 10%, >8
            si[4] = "Short and put"
          end
        else
          # No, Middle 80%, Any Dist
          si[4] = "No action"
        end
      end     
      # instantiate display objects
      si_lg_import << DisplayItem.new(
        classification: "large", 
        set_created_at: disp_set_created_at,
        symbol: si[0],
        exchange: si[1],
        company: si[2],
        in_pf: si[3],
        rec_action: si[4],
        action: si[5],
        total_score: si[6],
        total_score_pct: si[7],
        dist_status: si[8],
        mkt_cap: si[9],
        nsi_score: si[10],
        ra_score: si[11],
        noas_score: si[12],
        ag_score: si[13],
        aita_score: si[14], 
        l52wp_score: si[15],
        pp_score: si[16],
        rq_score: si[17],
        dt2_score: si[18],
        prev_ed: si[19],
        next_ed: si[20],
        lm_revenue: si[21]
      )
      
    end
    
    # import lg_cap
    DisplayItem.import si_lg_import
    
    
    ##########################
    # Get Small Cap Listings #
    ##########################
    
    count_sm = si_pool_sm.count
    # 0. net_stock_issues, 1. rel_accruals, 2. net_op_assets_scaled, 3. assets_growth, 4. invest_to_assets, 5. adj_invest_to_assets, 6. l_52_wk_price, 7. profit_prem, 8. roa_q, 9. dist_total_2
    param_array = si_pool_sm.map { |si| [si.net_stock_issues, si.rel_accruals, si.net_op_assets_scaled, si.assets_growth, si.invest_to_assets, si.adj_invest_to_assets, si.l_52_wk_price, si.profit_prem, si.roa_q, si.dist_total_2] }
    
    # transpose to get arrays of each separate category
    net_stock_issues_array, rel_accruals_array, net_op_assets_scaled_array, assets_growth_array, invest_to_assets_array, adj_invest_to_assets_array, l_52_wk_price_array, profit_prem_array, roa_q_array, dist_total_2_array = param_array.transpose
    
    # sort each category array
    net_stock_issues_array = net_stock_issues_array.sort
    rel_accruals_array = rel_accruals_array.sort
    net_op_assets_scaled_array = net_op_assets_scaled_array.sort
    assets_growth_array = assets_growth_array.sort
    #invest_to_assets_array = invest_to_assets_array.sort  # Can't sort nil
    adj_invest_to_assets_array = adj_invest_to_assets_array.sort
    l_52_wk_price_array = l_52_wk_price_array.sort
    profit_prem_array = profit_prem_array.sort
    roa_q_array = roa_q_array.sort
    dist_total_2_array = dist_total_2_array.sort
    
    si_sm = []
    si_sm_import = []
    #process data
    si_pool_sm.each do |si|
      # set net_stock_issues rank
      # count net_stock_issues below 1
      disc_nsi = net_stock_issues_array.count { |nsi| nsi < 1 }
      nsi_rank_raw = net_stock_issues_array.index(si.net_stock_issues) + 1 - disc_nsi
      nsi_rank = si.net_stock_issues < 1 ? 1 : (nsi_rank_raw / ((count_sm - disc_nsi) / 9.0)).ceil + 1
      # set rel_accruals_rank
      ra_rank_raw = rel_accruals_array.index(si.rel_accruals) + 1
      ra_rank = (ra_rank_raw / (count_sm / 10.0)).ceil
      # set net_op_assets_scaled_rank
      noas_rank_raw = net_op_assets_scaled_array.index(si.net_op_assets_scaled) + 1
      noas_rank = (noas_rank_raw / (count_sm / 10.0)).ceil
      # set assets_growth_rank
      ag_rank_raw = assets_growth_array.index(si.assets_growth) + 1
      ag_rank = (ag_rank_raw / (count_sm / 10.0)).ceil
      # set adj_invest_to_assets_rank
      aita_rank_raw = adj_invest_to_assets_array.index(si.adj_invest_to_assets) + 1
      aita_rank = (aita_rank_raw / (count_sm / 10.0)).ceil ##### Revisit
      # set l_52_wk_price_rank (reverse array for inverse point system)
      l52wp_rank_raw = l_52_wk_price_array.reverse.index(si.l_52_wk_price) + 1
      l52wp_rank = (l52wp_rank_raw / (count_sm / 10.0)).ceil
      # set profit_prem_rank (reverse array for inverse point system)
      pp_rank_raw = profit_prem_array.reverse.index(si.profit_prem) + 1
      pp_rank = (pp_rank_raw / (count_sm / 10.0)).ceil
      # set roa_q_rank (reverse array for inverse point system)
      rq_rank_raw = roa_q_array.reverse.index(si.roa_q) + 1
      rq_rank = (rq_rank_raw / (count_sm / 10.0)).ceil
      # set dist_total_2_rank
      dt2_rank_raw = dist_total_2_array.index(si.dist_total_2) + 1
      dt2_rank = (dt2_rank_raw / (count_sm / 10.0)).ceil
      # set next and prev earnings dates
      prev_ed = si.stock.earnings_dates.where('date < ?', Date.today)
      next_ed = si.stock.earnings_dates.where('date >= ?', Date.today)
      
      total_score = [nsi_rank, ra_rank, noas_rank, ag_rank, aita_rank, l52wp_rank, pp_rank, rq_rank, dt2_rank].sum
      
      # 0. symbol, 1. exchange, 2. company, 3. in pf, 4. rec action, 5. action, 6. total score, 7. total score pct, 8. Dist >7/8, 9. Mkt Cap, 10. NSI, 11. RA, 12. NOAS, 13. AG, 14. AITA, 15. L52WP, 16. PP, 17. RQ, 18. DT2, 19. Previous Earnings, 20. Next Earnings, 21. LM Rev
      si_sm << [
        si.stock.symbol, 
        si.stock.exchange,
        si.stock.si_description,
        portfolio_securities.include?(si.stock.symbol) ? "Yes" : "No",
        "ph", #rec action
        "ph", #action
        total_score,
        nil, #total score percentile (move down)
        nil, #Dist top10% > 7 or bottom10% > 8 (move down)
        si.stock.market_cap,
        nsi_rank,
        ra_rank,
        noas_rank,
        ag_rank,
        aita_rank,
        l52wp_rank,
        pp_rank,
        rq_rank,
        dt2_rank,
        prev_ed.empty? ? "N/A" : (Date.today - prev_ed.last.date).to_i,
        next_ed.empty? ? "N/A" : (next_ed.last.date - Date.today).to_i == 0 ? 0.1 : (next_ed.last.date - Date.today).to_i,
        si.stock.lm_revenue
      ]
    end
    # calculate total score percentile (si[7]) and dist > 7 or 8 (si[8]) after initial setup
    ts_array = si_sm.map { |si| si[6] }.sort
    si_sm.each do |si| 
      si[7] = 1 - ((ts_array.index(si[6]) + 1)/ts_array.length.to_f)
      
      # set dist
      if si[7] >= 0.9
        si[8] = si[18] > 7 ? "Yes" : "No"
      elsif si[7] <= 0.1
        si[8] = si[18] > 8 ? "Yes" : "No"
      else
        si[8] = "N/A"
      end
      
      # set programmatic actions
      if si[3] == "Yes"
        if si[7] >= 0.9
          if si[18] <= 7
            # Yes, Top 10%, <=7
            si[4] = "Hold or add"
          else
            # Yes, Top 10%, >7
            si[4] = "Hold or sell"
          end
        elsif si[7] <= 0.1
          # Yes, Bottom 10%, Any Dist
          si[4] = "Sell"
        else
          # Yes, Middle 80%, Any Dist
          si[4] = "Close"
        end
      else
        if si[7] >= 0.9
          if si[18] <= 7
            # No, Top 10%, <=7
            si[4] = "Long and call"
          else
            # No, Top 10%, >7
            si[4] = "Long and call"
          end
        elsif si[7] <= 0.1
          if si[18] <= 8
            # No, Bottom 10%, <=8
            si[4] = "No action"
          else
            # No, Bottom 10%, >8
            si[4] = "No action"
          end
        else
          # No, Middle 80%, Any Dist
          si[4] = "No action"
        end
      end
      # instantiate objects
      si_sm_import << DisplayItem.new(
        classification: "small", 
        set_created_at: disp_set_created_at,
        symbol: si[0],
        exchange: si[1],
        company: si[2],
        in_pf: si[3],
        rec_action: si[4],
        action: si[5],
        total_score: si[6],
        total_score_pct: si[7],
        dist_status: si[8],
        mkt_cap: si[9],
        nsi_score: si[10],
        ra_score: si[11],
        noas_score: si[12],
        ag_score: si[13],
        aita_score: si[14], 
        l52wp_score: si[15],
        pp_score: si[16],
        rq_score: si[17],
        dt2_score: si[18],
        prev_ed: si[19],
        next_ed: si[20],
        lm_reveneu: si[21]
      )
    end
    # import sm_cap
    DisplayItem.import si_sm_import
  end
end