class PagesController < ApplicationController
  before_action :set_page, only: [:show, :edit, :update, :destroy]

  # GET /pages
  # GET /pages.json
  def index
    @pages = Page.all
  end
  
  def analysis  
    # portfolio items
    pi_set_date_array = PortfolioItem.all.map { |pi| pi.set_created_at }.uniq.sort
    @pi_period = params['pi_period'] ||= pi_set_date_array.last
    pi_pool = PortfolioItem.where(set_created_at: pi_period)
    
    # array of portfolio symbols
    portfolio_securities = pi_pool.map { |pi| pi.stock.symbol }
    
    # screen item variables and arrays
    si_set_date_array = ScreenItem.all.map { |si| si.set_created_at }.uniq.sort
    @si_period = params['si_period'] ||= si_set_date_array.last
    si_pool = ScreenItem.where(set_created_at: si_period)
    
    # set cap_separator
    separator = MathStuff.median(si_pool.map { |si| si.stock.market_cap })
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
    
    @si_lg = []
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
      
      total_score = [nsi_rank, ra_rank, noas_rank, ag_rank, aita_rank, l52wp_rank, pp_rank, rq_rank, dt2_rank].sum
      
      # 0. symbol, 1. exchange, 2. company, 3. in pf, 4. rec action, 5. action, 6. total score, 7. total score pct, 8. Dist >7/8, 9. Mkt Cap, 10. NSI, 11. RA, 12. NOAS, 13. AG, 14. AITA, 15. L52WP, 16. PP, 17. RQ, 18. DT2
      @si_lg << [
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
        dt2_rank
      ]
    end
    # calculate programmatic action (si[4]), total score percentile (si[7]) and dist > 7 or 8 (si[8]) after initial setup
    ts_array = @si_lg.map { |si| si[6] }.sort
    @si_lg.each do |si| 
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
    end
    @si_lg.sort_by! { |si| si[6] }
    
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
    
    @si_sm = []
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
      # set large_cap/small_cap
      
      total_score = [nsi_rank, ra_rank, noas_rank, ag_rank, aita_rank, l52wp_rank, pp_rank, rq_rank, dt2_rank].sum
      
      # 0. symbol, 1. exchange, 2. company, 3. in pf, 4. rec action, 5. action, 6. total score, 7. total score pct, 8. Dist >7/8, 9. Mkt Cap, 10. NSI, 11. RA, 12. NOAS, 13. AG, 14. AITA, 15. L52WP, 16. PP, 17. RQ, 18. DT2
      @si_sm << [
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
        dt2_rank
      ]
    end
    # calculate total score percentile (si[7]) and dist > 7 or 8 (si[8]) after initial setup
    ts_array = @si_sm.map { |si| si[6] }.sort
    @si_sm.each do |si| 
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
    end
    @si_sm.sort_by! { |si| si[6] }
  end

  # GET /pages/1
  # GET /pages/1.json
  def show
  end

  # GET /pages/new
  def new
    @page = Page.new
  end

  # GET /pages/1/edit
  def edit
  end

  # POST /pages
  # POST /pages.json
  def create
    @page = Page.new(page_params)

    respond_to do |format|
      if @page.save
        format.html { redirect_to @page, notice: 'Page was successfully created.' }
        format.json { render :show, status: :created, location: @page }
      else
        format.html { render :new }
        format.json { render json: @page.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /pages/1
  # PATCH/PUT /pages/1.json
  def update
    respond_to do |format|
      if @page.update(page_params)
        format.html { redirect_to @page, notice: 'Page was successfully updated.' }
        format.json { render :show, status: :ok, location: @page }
      else
        format.html { render :edit }
        format.json { render json: @page.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /pages/1
  # DELETE /pages/1.json
  def destroy
    @page.destroy
    respond_to do |format|
      format.html { redirect_to pages_url, notice: 'Page was successfully destroyed.' }
      format.json { head :no_content }
    end
  end
  
  def import_pi
    if params[:file].nil?
      redirect_to root_url, alert: "Please select a compatible file to import."
    else
      PortfolioItem.import(params[:file])
      redirect_to root_url, notice: "Portfolio data being processed; this will take about a minute."
    end
  end

  def import_si
    if params[:file].nil?
      redirect_to root_url, alert: "Please select a compatible file to import."
    else
      ScreenItem.import(params[:file])
      redirect_to root_url, notice: "Screen data being processed; this will take a minute or two."
    end
  end
  
  def auto_import_si
    GetScreenMechanizeWorker.perform_async
    redirect_to root_url, notice: "Screen data being gathered and processed; this may take 10-20 minutes."
  end
  

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_page
      @page = Page.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def page_params
      params.fetch(:page, {})
    end
end
