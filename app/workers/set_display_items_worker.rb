# Worker for setting display items for analysis page
class SetDisplayItemsWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'high', unique: :until_executed
  
  def perform
    # clear out current DisplayItem set
    DisplayItem.destroy_all
    
    # set threshold for previous earnings to be labeled as "recent"
    rec_earn = 180
    
    disp_set_created_at = DateTime.now
    portfolio_items = PortfolioItem.all.includes(:stock, :stock => :earnings_dates)
    screen_items = ScreenItem.all.includes(:stock, :stock => :earnings_dates)
    portfolio_only = Stock.all.map { |s| s.portfolio_items if !s.portfolio_items.empty? && s.screen_items.empty? }.compact.flatten
    
    # portfolio items
    pi_set_date_array = portfolio_items.pluck(:set_created_at).uniq.sort
    pi_period = pi_set_date_array.last
    pi_pool = portfolio_items.where(set_created_at: pi_period)
    # portfolio-only
    po_pool = portfolio_only.select { |po| po.set_created_at == pi_period }
    
    # array of portfolio symbols
    portfolio_securities = pi_pool.pluck(:'stocks.symbol')
    
    # screen item variables and arrays
    si_set_date_array = screen_items.pluck(:set_created_at).uniq.sort
    si_period = si_set_date_array.last
    si_pool = screen_items.where(set_created_at: si_period)
    
    # separate small and large cap
    si_pool_lg = si_pool.where(classification: "large")
    si_pool_sm = si_pool.where(classification: "small")
    
    # accumulate data as code runs
    long_mkt_cap_pool = 0
    short_mkt_cap_pool = 0
    buy_val = 0
    return_funds = 0
    
    # market value of PI that have no SI (fallen out)
    fallen_out_val = portfolio_items.map { |pi| pi.last * pi.quantity if pi.stock.screen_items.empty? && pi.pos_type == "stock" }.compact.sum.to_f
    
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
      
      portfolio = si.stock.portfolio_items.find_by(pos_type: "stock")
      
      # 0. symbol, 1. exchange, 2. company, 3. in pf, 4. rec action, 5. action, 6. total score, 7. total score pct, 8. Dist >7/8, 9. Mkt Cap, 10. NSI, 11. RA, 12. NOAS, 13. AG, 14. AITA, 15. L52WP, 16. PP, 17. RQ, 18. DT2, 19. Previous Earnings, 20. Next Earnings, 21. LQ Rev, 22. Current Position
      si_lg << [
        si.stock.symbol, 
        si.stock.exchange,
        si.stock.si_description,
        portfolio_securities.include?(si.stock.symbol) ? "Yes" : "No",
        "ph", #rec action
        si.stock.actions.empty? ? "N/A" : si.stock.actions.last.description, #action
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
        si.stock.lq_revenue,
        !portfolio.nil? ? portfolio.last * portfolio.quantity * ( portfolio.position == "long" ? 1 : -1 ) : 0
      ]
    end
    # calculate programmatic action (si[4]), total score percentile (si[7]) and dist > 7 or 8 (si[8]) after initial setup
    ts_array = si_lg.map { |si| si[6] }.sort
    si_lg.each do |si| 
      stock = Stock.find_by(symbol: si[0], exchange: si[1])
      positions = stock.portfolio_items.map { |pi| pi.op_type.nil? ? pi.position : pi.op_type == "Put" ? "short" : "long" }.uniq
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
      # si[3] - in portfolio
      # si[4] - recommended action
      # si[7] - total score percentile
      
      # set prev_earn to comparable number (change N/As to safe high number)
      si[19] == "N/A" ? prev_earn = 365 : prev_earn = si[19]
      
      # if in portfolio
      if si[3] == "Yes"
        # if there are no conflicting positions (long vs short underlying security)
        if positions.count == 1
          # if the position is short
          if positions[0] == "short"
            case 
            # in top 10%
            when si[7] >= 0.9 && prev_earn <= rec_earn
              si[4] = "CLOSE AND BUY"
              return_funds = return_funds + si[22].abs
              long_mkt_cap_pool = long_mkt_cap_pool + stock.market_cap
            # in bottom 15%
            when si[7] <= 0.15 || prev_earn > rec_earn
              si[4] = "HOLD"
              short_mkt_cap_pool = short_mkt_cap_pool + stock.market_cap
            # in middle 75%
            else
              si[4] = "CLOSE"
              return_funds = return_funds + si[22].abs
            end
          # if the position is long
          else
            case 
            # in top 15%
            when si[7] >= 0.85 || prev_earn > rec_earn
              si[4] = "HOLD"
              long_mkt_cap_pool = long_mkt_cap_pool + stock.market_cap
            # in bottom 10%
            when si[7] <= 0.1 && prev_earn <= rec_earn
              si[4] = "CLOSE AND SHORT"
              return_funds = return_funds + si[22].abs
              short_mkt_cap_pool = short_mkt_cap_pool + stock.market_cap
            # in middle 75%
            else
              si[4] = "CLOSE"
              return_funds = return_funds + si[22].abs
            end
          end
        # if positions are conflicting
        else
          si[4] = "!!! L & S"
        end
      # if not in portfolio
      else
        case
        # if in top 10%
        when si[7] >= 0.9
          si[4] = "BUY"
          long_mkt_cap_pool = long_mkt_cap_pool + stock.market_cap unless si[19] == "N/A"
        # if in bottom 10%
        when si[7] <= 0.1
          si[4] = "SHORT"
          short_mkt_cap_pool = short_mkt_cap_pool + stock.market_cap unless si[19] == "N/A"
        # if in middle 80%
        else
          si[4] = "(n/a)"
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
        lq_revenue: si[21],
        curr_portfolio: si[22]
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
      
      portfolio = si.stock.portfolio_items.find_by(pos_type: 'stock')
      
      # 0. symbol, 1. exchange, 2. company, 3. in pf, 4. rec action, 5. action, 6. total score, 7. total score pct, 8. Dist >7/8, 9. Mkt Cap, 10. NSI, 11. RA, 12. NOAS, 13. AG, 14. AITA, 15. L52WP, 16. PP, 17. RQ, 18. DT2, 19. Previous Earnings, 20. Next Earnings, 21. LQ Rev, 22. Current Position
      si_sm << [
        si.stock.symbol, 
        si.stock.exchange,
        si.stock.si_description,
        portfolio_securities.include?(si.stock.symbol) ? "Yes" : "No",
        "ph", #rec action
        si.stock.actions.empty? ? "N/A" : si.stock.actions.last.description, #action
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
        si.stock.lq_revenue,
        !portfolio.nil? ? portfolio.last * portfolio.quantity * ( portfolio.position == "long" ? 1 : -1 ) : 0
      ]
    end
    # calculate programmatic action (si[4]), total score percentile (si[7]), and dist > 7 or 8 (si[8]) after initial setup
    ts_array = si_sm.map { |si| si[6] }.sort
    si_sm.each do |si|       
      stock = Stock.find_by(symbol: si[0], exchange: si[1])
      positions = stock.portfolio_items.map { |pi| pi.op_type.nil? ? pi.position : pi.op_type == "Put" ? "short" : "long" }.uniq
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
      # si[3] - in portfolio
      # si[4] - recommended action
      # si[7] - total score percentile
            
      # set prev_earn to comparable number (change N/As to safe high number)
      si[19] == "N/A" ? prev_earn = 365 : prev_earn = si[19]
      
      # if in portfolio
      if si[3] == "Yes"
        # if there are no conflicting positions (long vs short underlying security)
        if positions.count == 1
          # if the position is short
          if positions[0] == "short"
            case 
            # in top 10%
            when si[7] >= 0.9
              si[4] = "CLOSE AND BUY" && prev_earn <= rec_earn
              return_funds = return_funds + si[22].abs
              long_mkt_cap_pool = long_mkt_cap_pool + stock.market_cap
            # in bottom 15%
            when si[7] <= 0.15
              si[4] = "HOLD" || prev_earn > rec_earn
              short_mkt_cap_pool = short_mkt_cap_pool + stock.market_cap
            # in middle 75%
            else
              si[4] = "CLOSE"
              return_funds = return_funds + si[22].abs
            end
          # if the position is long
          else
            case 
            # in top 15%
            when si[7] >= 0.85
              si[4] = "HOLD" || prev_earn > rec_earn
              long_mkt_cap_pool = long_mkt_cap_pool + stock.market_cap
            # in bottom 10%
            when si[7] <= 0.1
              si[4] = "CLOSE AND SHORT" && prev_earn <= rec_earn
              return_funds = return_funds + si[22].abs
              short_mkt_cap_pool = short_mkt_cap_pool + stock.market_cap
            # in middle 75%
            else
              si[4] = "CLOSE"
              return_funds = return_funds + si[22].abs
            end
          end
        # if positions are conflicting
        else
          si[4] = "!!! L & S"
        end
      # if not in portfolio
      else
        case
        # if in top 10%
        when si[7] >= 0.9
          si[4] = "BUY"
          long_mkt_cap_pool = long_mkt_cap_pool + stock.market_cap unless si[19] == "N/A"
        # if in bottom 10%
        when si[7] <= 0.1
          si[4] = "SHORT"
          short_mkt_cap_pool = short_mkt_cap_pool + stock.market_cap unless si[19] == "N/A"
        # if in middle 80%
        else
          si[4] = "(n/a)"
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
        lq_revenue: si[21],
        curr_portfolio: si[22]
      )
    end
    # import sm_cap
    DisplayItem.import si_sm_import
    
    ############################
    # Get all fallen out items #
    ############################
    
    po = []
    po_import = []
    #process data
    po_pool.each do |pi|
      sym = pi.stock.symbol
      next if pi.pos_type == "option" && po_pool.find { |pi| pi.stock.symbol == sym && pi.pos_type == "stock" }
      # set next and prev earnings dates
      prev_ed = pi.stock.earnings_dates.where('date < ?', Date.today)
      next_ed = pi.stock.earnings_dates.where('date >= ?', Date.today)

      # 0. symbol, 1. exchange, 2. company, 3. in pf, 4. rec action, 5. action, 6. total score, 7. total score pct, 8. Dist >7/8, 9. Mkt Cap, 10. NSI, 11. RA, 12. NOAS, 13. AG, 14. AITA, 15. L52WP, 16. PP, 17. RQ, 18. DT2, 19. Previous Earnings, 20. Next Earnings, 21. LQ Rev, 22. Current Position
      po << [
        pi.stock.symbol, 
        pi.stock.exchange,
        pi.stock.si_description,
        portfolio_securities.include?(pi.stock.symbol) ? "Yes" : "No",
        "HOLD", #rec action
        pi.stock.actions.empty? ? "N/A" : pi.stock.actions.last.description, #action
        "N/A",
        "N/A", #total score percentile (move down)
        "N/A", #Dist top10% > 7 or bottom10% > 8 (move down)
        pi.stock.market_cap,
        "N/A",
        "N/A",
        "N/A",
        "N/A",
        "N/A",
        "N/A",
        "N/A",
        "N/A",
        "N/A",
        prev_ed.empty? ? "N/A" : (Date.today - prev_ed.last.date).to_i,
        next_ed.empty? ? "N/A" : (next_ed.last.date - Date.today).to_i == 0 ? 0.1 : (next_ed.last.date - Date.today).to_i,
        pi.stock.lq_revenue,
        pi.last * pi.quantity * ( pi.position == "long" ? 1 : -1 )
      ]
    end
    po.each do |pi| 
      # instantiate display objects
      po_import << DisplayItem.new(
        classification: "fallen out", 
        set_created_at: disp_set_created_at,
        symbol: pi[0],
        exchange: pi[1],
        company: pi[2],
        in_pf: pi[3],
        rec_action: pi[4],
        action: pi[5],
        total_score: pi[6],
        total_score_pct: pi[7],
        dist_status: pi[8],
        mkt_cap: pi[9],
        nsi_score: pi[10],
        ra_score: pi[11],
        noas_score: pi[12],
        ag_score: pi[13],
        aita_score: pi[14], 
        l52wp_score: pi[15],
        pp_score: pi[16],
        rq_score: pi[17],
        dt2_score: pi[18],
        prev_ed: pi[19],
        next_ed: pi[20],
        lq_revenue: pi[21],
        curr_portfolio: pi[22]
      )
      
    end
    
    # import fallen out
    DisplayItem.import po_import
  
    ###################################################
    
    # associate stocks with display_items
    display_items = DisplayItem.all.includes(:portfolio_items)
    stocks = Stock.all
    display_items.each { |di| di.stock = stocks.find_by(symbol: di.symbol, exchange: di.exchange) }
    # destroy any display items that don't have an associated stock as a fail-safe (WBT/MFS pointed this error out)
    display_items.includes(:stock).where(stocks: {id: nil}).destroy_all
    
    # set allocations; assume Cash is "gross cash"
    long_val = portfolio_items.where(pos_type: "stock", position: "long").map { |pi| pi.market_val }.sum
    short_val = portfolio_items.where(pos_type: "stock", position: "short").map { |pi| pi.market_val.abs }.sum
    option_val = portfolio_items.where(pos_type: "option").map { |pi| pi.market_val.abs }.sum
    #portfolio_value = portfolio_items.map { |pi| pi.market_val.abs }.compact.sum + Cash.first.amount
    #funds_for_alloc = portfolio_value - fallen_out_val - portfolio_items.where(pos_type: 'option').map { |pi| pi.market_val.abs }.compact.sum
    capacity = 2 * (long_val + (Cash.first.amount - short_val) - 200000) - option_val - fallen_out_val
    # halve allocation funds to split between long and short
    funds_for_alloc = capacity / 2
    display_items = DisplayItem.where('rec_action != ? AND classification != ?', "(n/a)", "fallen out")
    display_items.each do |di| 
      di.prev_ed == "N/A" ? prev_earn = 365 : prev_earn = di.prev_ed.to_i
      if di.rec_action == "CLOSE"
        rec = 0
      else
        # indicate whether total should be negative
        if (di.rec_action == "HOLD" && di.curr_portfolio < 0) || di.rec_action["SHORT"]
          sign = -1
          mkt_cap_base = short_mkt_cap_pool
        else
          sign = 1
          mkt_cap_base = long_mkt_cap_pool
        end
        if (prev_earn > rec_earn) && (di.rec_action["BUY"] || di.rec_action["SHORT"])
          rec = 0
        else
          rec = (di.mkt_cap.to_f / mkt_cap_base) * funds_for_alloc * sign
        end
      end
      change = rec - di.curr_portfolio
      di.update(rec_portfolio: rec, net_portfolio: change)
    end
  end
end

DisplayItem.all.map { |di| di.rec_portfolio.abs unless di.rec_portfolio.nil? }.compact.sum