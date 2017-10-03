class PagesController < ApplicationController
  before_action :set_page, only: [:show, :edit, :update, :destroy]
  before_action :set_update_times, only: [:index, :analysis]
  before_action :set_workers, only: [:index, :analysis]

  # GET /pages
  # GET /pages.json
  def index
    @pages = Page.all
  end
  
  def analysis
    # eager load display_items
    display_items = DisplayItem.all.includes(:portfolio_items)
    portfolio_items = PortfolioItem.all.includes(:stock)
    
    if Rails.env == "production" && Sidekiq::Stats.new.workers_size > 0
      redirect_to :back, alert: "Screen or portfolio data are still being compiled, or analysis data are being processed; please try again momentarily."
    end
    #screen item variables and arrays
    si_pool_lg = display_items.where(classification: "large")
    si_pool_sm = display_items.where(classification: "small")
    po_pool = display_items.where(classification: "fallen out")
    @si_lg = si_pool_lg.map { |si| [si.symbol, si.exchange, si.company, si.in_pf, si.rec_action, si.action, si.total_score, si.total_score_pct, si.dist_status, si.mkt_cap, si.nsi_score, si.ra_score, si.noas_score, si.ag_score, si.aita_score, si.l52wp_score, si.pp_score, si.rq_score, si.dt2_score, si.prev_ed, si.next_ed, si.lq_revenue, si.stock.portfolio_items, si.rec_portfolio, si.curr_portfolio, si.net_portfolio] }.sort_by { |si| si[7] }.reverse!
    
    @si_sm = si_pool_sm.map { |si| [si.symbol, si.exchange, si.company, si.in_pf, si.rec_action, si.action, si.total_score, si.total_score_pct, si.dist_status, si.mkt_cap, si.nsi_score, si.ra_score, si.noas_score, si.ag_score, si.aita_score, si.l52wp_score, si.pp_score, si.rq_score, si.dt2_score, si.prev_ed, si.next_ed, si.lq_revenue, si.stock.portfolio_items, si.rec_portfolio, si.curr_portfolio, si.net_portfolio] }.sort_by { |si| si[7] }.reverse!
    
    # for development, just replicate lg pool (so there are multiple tabs of data)
    if Rails.env == "development"
      @si_lg = @si_sm
    end
    @po = po_pool.map { |pi| [pi.symbol, pi.exchange, pi.company, pi.in_pf, pi.rec_action, pi.action, pi.total_score, pi.total_score_pct, pi.dist_status, pi.mkt_cap, pi.nsi_score, pi.ra_score, pi.noas_score, pi.ag_score, pi.aita_score, pi.l52wp_score, pi.pp_score, pi.rq_score, pi.dt2_score, pi.prev_ed, pi.next_ed, pi.lq_revenue, pi.stock.portfolio_items] }.sort_by { |pi| pi[7] }.reverse!
    
    ######################
    # SUMMARY STATISTICS #
    ######################
    
    #@fallen_out_val = portfolio_items.map { |pi| pi.last * pi.quantity if pi.stock.screen_items.empty? && pi.pos_type == "stock" }.compact.sum.to_f ####more intensive search
    @fallen_out_val = display_items.where(classification: "fallen out").map { |di| di.curr_portfolio.abs }.compact.sum
    if Rails.env == "production"
      @close_val = display_items.where('rec_action ~* ?', 'CLOSE').map { |di| di.curr_portfolio.abs }.compact.sum
    else
      @close_val = display_items.where('rec_action LIKE ?', 'CLOSE').map { |di| di.curr_portfolio.abs }.compact.sum
    end
    @longs_val = portfolio_items.where(pos_type: "stock", position: "long").map { |pi| pi.market_val.abs }.sum.to_f
    @cash = Cash.last.amount
    @shorts_val = portfolio_items.where(pos_type: "stock", position: "short").map { |pi| pi.market_val.abs }.sum.to_f
    @reserve_val = 200000
    
    @non_margin_investable = @longs_val + @cash - @shorts_val - @reserve_val
    @total_investable = @non_margin_investable * 2
    
    @option_val = portfolio_items.where(pos_type: "option").map { |pi| pi.market_val.abs }.sum.to_f
    
    portfolio_val = portfolio_items.map { |pi| pi.market_val.abs }.compact.sum + Cash.first.amount
    
    @alloc_funds = portfolio_val - @fallen_out_val - @option_val
    # funds to allocate:  2 * (Longs + (Cash - Shorts) - 200k) - Opt - NSH
    @purchasing_capacity = 2 * (@longs_val + (@cash - @shorts_val) - @reserve_val) - @option_val - @fallen_out_val
    @capacity_per_type = @purchasing_capacity / 2
    
    # current recommended portfolio balance (excluding reserve, NSH, and options)
    @rec_long = display_items.where('rec_portfolio > ?', 0).map { |di| di.rec_portfolio }.sum
    @rec_short = display_items.where('rec_portfolio < ?', 0).map { |di| di.rec_portfolio }.sum
    @rec_total_inv = @rec_long + @rec_short.abs
    
    ##################
    # MKT CAP SHARES #
    ##################
    
    if Rails.env == "production"
      longs = display_items.where('rec_action ~* ? AND rec_portfolio > ?', "BUY", 0)
      lg_longs = display_items.where('rec_action ~* ? AND rec_portfolio > ? AND classification = ?', "BUY", 0, "large")
      sm_longs = display_items.where('rec_action ~* ? AND rec_portfolio > ? AND classification = ?', "BUY", 0, "small")
      shorts = display_items.where('rec_action ~* ? AND rec_portfolio < ?', "SHORT", 0)
      lg_shorts = display_items.where('rec_action ~* ? AND rec_portfolio < ? AND classification = ?', "SHORT", 0, "large")
      sm_shorts = display_items.where('rec_action ~* ? AND rec_portfolio < ? AND classification = ?', "SHORT", 0, "small")
    else
      longs = display_items.where('rec_action LIKE ? AND rec_portfolio > ?', "BUY", 0)
      lg_longs = display_items.where('rec_action LIKE ? AND rec_portfolio > ? AND classification = ?', "BUY", 0, "large")
      sm_longs = display_items.where('rec_action LIKE ? AND rec_portfolio > ? AND classification = ?', "BUY", 0, "small")
      shorts = display_items.where('rec_action LIKE ? AND rec_portfolio < ?', "SHORT", 0)
      lg_shorts = display_items.where('rec_action LIKE ? AND rec_portfolio < ? AND classification = ?', "SHORT", 0, "large")
      sm_shorts = display_items.where('rec_action LIKE ? AND rec_portfolio < ? AND classification = ?', "SHORT", 0, "small")
    end
    
    # TOTAL #
    @long_mkt_cap = longs.map { |di| di.stock.market_cap }.sum.to_f
    @short_mkt_cap = shorts.map { |di| di.stock.market_cap }.sum.to_f
    
    @hold_mkt_cap = display_items.where('rec_action = ? AND classification != ?', 'HOLD', 'fallen out').map { |di| di.stock.market_cap }.sum.to_f
    @long_hold_mkt_cap = display_items.where('rec_action = ? AND rec_portfolio > ? AND classification != ?', 'HOLD', 0, 'fallen out').map { |di| di.stock.market_cap }.sum.to_f
    @short_hold_mkt_cap = display_items.where('rec_action = ? AND rec_portfolio < ? AND classification != ?', 'HOLD', 0, 'fallen out').map { |di| di.stock.market_cap }.sum.to_f
    @tot_mkt_cap = @long_mkt_cap + @short_mkt_cap + @long_hold_mkt_cap + @short_hold_mkt_cap
    
    @long_share = @long_mkt_cap / @tot_mkt_cap
    @short_share = @short_mkt_cap / @tot_mkt_cap
    @long_hold_share = @long_hold_mkt_cap / @tot_mkt_cap
    @short_hold_share = @short_hold_mkt_cap / @tot_mkt_cap
    @tot_hold_share = @hold_mkt_cap / @tot_mkt_cap
    @total_share = @long_share + @short_share + @long_hold_share + @short_hold_share
    
    # LARGE #
    @lg_long_mkt_cap = lg_longs.map { |di| di.stock.market_cap }.sum.to_f
    @lg_short_mkt_cap = lg_shorts.map { |di| di.stock.market_cap }.sum.to_f
    
    @lg_hold_mkt_cap = display_items.where('rec_action = ? AND classification = ?', 'HOLD', 'large').map { |di| di.stock.market_cap }.sum.to_f
    @lg_long_hold_mkt_cap = display_items.where('rec_action = ? AND rec_portfolio > ? AND classification = ?', 'HOLD', 0, 'large').map { |di| di.stock.market_cap }.sum.to_f
    @lg_short_hold_mkt_cap = display_items.where('rec_action = ? AND rec_portfolio < ? AND classification = ?', 'HOLD', 0, 'large').map { |di| di.stock.market_cap }.sum.to_f
    @lg_tot_mkt_cap = @long_mkt_cap + @short_mkt_cap + @long_hold_mkt_cap + @short_hold_mkt_cap

    @lg_long_share = @lg_long_mkt_cap / @tot_mkt_cap
    @lg_short_share = @lg_short_mkt_cap / @tot_mkt_cap
    @lg_long_hold_share = @lg_long_hold_mkt_cap / @tot_mkt_cap
    @lg_short_hold_share = @lg_short_hold_mkt_cap / @tot_mkt_cap
    @lg_tot_hold_share = @lg_hold_mkt_cap / @tot_mkt_cap
    @lg_total_share = @lg_long_share + @lg_short_share + @lg_long_hold_share + @lg_short_hold_share
    
    # SMALL #
    @sm_long_mkt_cap = sm_longs.map { |di| di.stock.market_cap }.sum.to_f
    @sm_short_mkt_cap = sm_shorts.map { |di| di.stock.market_cap }.sum.to_f
    
    @sm_hold_mkt_cap = display_items.where('rec_action = ? AND classification = ?', 'HOLD', 'small').map { |di| di.stock.market_cap }.sum.to_f
    @sm_long_hold_mkt_cap = display_items.where('rec_action = ? AND rec_portfolio > ? AND classification = ?', 'HOLD', 0, 'small').map { |di| di.stock.market_cap }.sum.to_f
    @sm_short_hold_mkt_cap = display_items.where('rec_action = ? AND rec_portfolio < ? AND classification = ?', 'HOLD', 0, 'small').map { |di| di.stock.market_cap }.sum.to_f
    @sm_tot_mkt_cap = @long_mkt_cap + @short_mkt_cap + @long_hold_mkt_cap + @short_hold_mkt_cap

    @sm_long_share = @sm_long_mkt_cap / @tot_mkt_cap
    @sm_short_share = @sm_short_mkt_cap / @tot_mkt_cap
    @sm_long_hold_share = @sm_long_hold_mkt_cap / @tot_mkt_cap
    @sm_short_hold_share = @sm_short_hold_mkt_cap / @tot_mkt_cap
    @sm_tot_hold_share = @sm_hold_mkt_cap / @tot_mkt_cap
    @sm_total_share = @sm_long_share + @sm_short_share + @sm_long_hold_share + @sm_short_hold_share
    
    #################
    # TARGET SHARES #
    #################
    
    # TOTAL #
    @long_targets = longs.map { |di| di.rec_portfolio }.sum.to_f
    @short_targets = shorts.map { |di| di.rec_portfolio.abs }.sum.to_f
    @hold_targets = display_items.where('rec_action = ? AND classification != ?', 'HOLD', 'fallen out').map { |di| di.rec_portfolio.abs }.sum.to_f
    @long_hold_targets = display_items.where('rec_action = ? AND rec_portfolio > ? AND classification != ?', 'HOLD', 0, 'fallen out').map { |di| di.rec_portfolio }.sum.to_f
    @short_hold_targets = display_items.where('rec_action = ? AND rec_portfolio < ? AND classification != ?', 'HOLD', 0, 'fallen out').map { |di| di.rec_portfolio.abs }.sum.to_f
    @tot_targets = @long_targets + @short_targets + @long_hold_targets + @short_hold_targets

    @long_target_share = @long_targets / @tot_targets
    @short_target_share = @short_targets / @tot_targets
    @long_hold_target_share = @long_hold_targets / @tot_targets
    @short_hold_target_share = @short_hold_targets / @tot_targets
    @tot_hold_target_share = @hold_targets / @tot_targets
    @total_target_share = @long_target_share + @short_target_share + @long_hold_target_share + @short_hold_target_share
    
    # LARGE #
    @lg_long_targets = lg_longs.map { |di| di.rec_portfolio }.sum.to_f
    @lg_short_targets = lg_shorts.map { |di| di.rec_portfolio.abs }.sum.to_f
    @lg_hold_targets = display_items.where('rec_action = ? AND classification = ?', 'HOLD', 'large').map { |di| di.rec_portfolio.abs }.sum.to_f
    @lg_long_hold_targets = display_items.where('rec_action = ? AND rec_portfolio > ? AND classification = ?', 'HOLD', 0, 'large').map { |di| di.rec_portfolio }.sum.to_f
    @lg_short_hold_targets = display_items.where('rec_action = ? AND rec_portfolio < ? AND classification = ?', 'HOLD', 0, 'large').map { |di| di.rec_portfolio.abs }.sum.to_f
    @lg_tot_targets = @lg_long_targets + @lg_short_targets + @lg_long_hold_targets + @lg_short_hold_targets

    @lg_long_target_share = @lg_long_targets / @tot_targets
    @lg_short_target_share = @lg_short_targets / @tot_targets
    @lg_long_hold_target_share = @lg_long_hold_targets / @tot_targets
    @lg_short_hold_target_share = @lg_short_hold_targets / @tot_targets
    @lg_tot_hold_target_share = @lg_hold_targets / @tot_targets
    @lg_total_target_share = @lg_long_target_share + @lg_short_target_share + @lg_long_hold_target_share + @lg_short_hold_target_share
    
    # SMALL #
    @sm_long_targets = sm_longs.map { |di| di.rec_portfolio }.sum.to_f
    @sm_short_targets = sm_shorts.map { |di| di.rec_portfolio.abs }.sum.to_f
    @sm_hold_targets = display_items.where('rec_action = ? AND classification = ?', 'HOLD', 'small').map { |di| di.rec_portfolio.abs }.sum.to_f
    @sm_long_hold_targets = display_items.where('rec_action = ? AND rec_portfolio > ? AND classification = ?', 'HOLD', 0, 'small').map { |di| di.rec_portfolio }.sum.to_f
    @sm_short_hold_targets = display_items.where('rec_action = ? AND rec_portfolio < ? AND classification = ?', 'HOLD', 0, 'small').map { |di| di.rec_portfolio.abs }.sum.to_f
    @sm_tot_targets = @sm_long_targets + @sm_short_targets + @sm_long_hold_targets + @sm_short_hold_targets

    @sm_long_target_share = @sm_long_targets / @tot_targets
    @sm_short_target_share = @sm_short_targets / @tot_targets
    @sm_long_hold_target_share = @sm_long_hold_targets / @tot_targets
    @sm_short_hold_target_share = @sm_short_hold_targets / @tot_targets
    @sm_tot_hold_target_share = @sm_hold_targets / @tot_targets
    @sm_total_target_share = @sm_long_target_share + @sm_short_target_share + @sm_long_hold_target_share + @sm_short_hold_target_share
    
    ##################
    # HOLDINGS CALCS #
    ##################
    
    # Present holdings + buys - close long + adj up -adj down (each 4 subs)

    # Large #
    @lg_current_holdings_long = display_items.where('classification = ? AND curr_portfolio > ?', 'large', 0).map { |di| di.curr_portfolio }.sum.to_f
    if Rails.env == "production"
      @lg_buys = display_items.where('classification = ? AND rec_action ~* ?', 'large', 'BUY').map { |di| di.rec_portfolio }.sum.to_f
      @lg_closes = display_items.where('classification = ? AND rec_action ~* ? AND curr_portfolio > ?', 'large', 'CLOSE', 0).map { |di| di.curr_portfolio }.sum.to_f
    else
      @lg_buys = display_items.where('classification = ? AND rec_action LIKE ?', 'large', 'BUY').map { |di| di.rec_portfolio }.sum.to_f
      @lg_closes = display_items.where('classification = ? AND rec_action LIKE ? AND curr_portfolio > ?', 'large', 'CLOSE', 0).map { |di| di.curr_portfolio }.sum.to_f
    end
    @lg_adj_up = display_items.where('classification = ? AND curr_portfolio > ? AND net_portfolio > ?', 'large', 0, 0).map { |di| di.net_portfolio }.sum.to_f
    @lg_adj_dn = display_items.where('classification = ? AND curr_portfolio > ? AND net_portfolio < ?', 'large', 0, 0).map { |di| di.net_portfolio }.sum.to_f
    #@lg_current_holdings_short = DisplayItem.where('classification = ? AND curr_portfolio < ?', 'large', 0).map { |di| di.curr_portfolio.abs }.sum.to_f
    
    @lg_total_after_adj = @lg_current_holdings_long + @lg_buys - @lg_closes + @lg_adj_up + @lg_adj_dn
    
    # Small #
    @sm_current_holdings_long = display_items.where('classification = ? AND curr_portfolio > ?', 'small', 0).map { |di| di.curr_portfolio }.sum.to_f
    if Rails.env == "production"
      @sm_buys = display_items.where('classification = ? AND rec_action ~* ?', 'small', 'BUY').map { |di| di.rec_portfolio }.sum.to_f
      @sm_closes = display_items.where('classification = ? AND rec_action ~* ? AND curr_portfolio > ?', 'small', 'CLOSE', 0).map { |di| di.curr_portfolio }.sum.to_f
    else
      @sm_buys = display_items.where('classification = ? AND rec_action LIKE ?', 'small', 'BUY').map { |di| di.rec_portfolio }.sum.to_f
      @sm_closes = display_items.where('classification = ? AND rec_action LIKE ? AND curr_portfolio > ?', 'small', 'CLOSE', 0).map { |di| di.curr_portfolio }.sum.to_f
    end
    @sm_adj_up = display_items.where('classification = ? AND curr_portfolio > ? AND net_portfolio > ?', 'small', 0, 0).map { |di| di.net_portfolio }.sum.to_f
    @sm_adj_dn = display_items.where('classification = ? AND curr_portfolio > ? AND net_portfolio < ?', 'small', 0, 0).map { |di| di.net_portfolio }.sum.to_f
    #@sm_current_holdings_short = DisplayItem.where('classification = ? AND curr_portfolio < ?', 'small', 0).map { |di| di.curr_portfolio.abs }.sum.to_f
    
    @sm_total_after_adj = @sm_current_holdings_long + @sm_buys - @sm_closes + @sm_adj_up + @sm_adj_dn
    
    # TOTAL #
    
    @tot_current_holdings_long = @sm_current_holdings_long + @lg_current_holdings_long
    @tot_buys = @sm_buys + @lg_buys
    @tot_closes = @sm_closes + @lg_closes
    @tot_adj_up = @sm_adj_up + @lg_adj_up
    @tot_adj_dn = @sm_adj_dn + @lg_adj_dn
    
    @tot_total_after_adj = @tot_current_holdings_long + @tot_buys - @tot_closes + @tot_adj_up + @tot_adj_dn
    
    #############
    # OLD CALCS #
    #############
    
    @tot_short = display_items.where('rec_portfolio < ?', 0).map { |di| di.rec_portfolio }.sum.abs
    @tot_long = display_items.where('rec_portfolio > ?', 0).map { |di| di.rec_portfolio }.sum.abs
    @net_allocate = @tot_short + @tot_long
    
    @total_portfolio_value = @option_val + @shorts_val + @longs_val + @cash
    @revised_portfolio_value = @total_portfolio_value - @option_val - @cash
    
    @net_investable = @revised_portfolio_value - @fallen_out_val + @cash # + @close_val ### remove @close_val for now (double-counted?)
    

    
    # @long_targets = display_items.where('rec_portfolio > ?', 0).map { |di| di.rec_portfolio }.sum
    # @short_targets = display_items.where('rec_portfolio < ?', 0).map { |di| di.rec_portfolio }.sum.abs
    # @tot_targets = @long_targets + @short_targets
    @remainder = @tot_targets - @net_investable
    
    @tot_curr_val = display_items.where.not(classification: 'fallen_out').map { |di| di.curr_portfolio.abs unless di.curr_portfolio.nil? }.compact.sum
    @tot_adj_val = display_items.map { |di| di.rec_portfolio - di.curr_portfolio unless di.rec_portfolio.nil? || di.curr_portfolio.nil? }.compact.sum
    @remainder_2 = @long_targets + @short_targets - @tot_curr_val - @tot_adj_val
  end
  
  def update_action
    symbol = eval(params['symbol'])[:value]
    exchange = eval(params['exchange'])[:value]
    action = eval(params['rec_action'])[:value]
    @id = "id-#{symbol}#{exchange}-action"
    commit = params['commit']
    stock = Stock.find_by(symbol: symbol, exchange: exchange)
    stock.actions.destroy_all
    if commit == "Confirm"
      time = Time.now.in_time_zone("Eastern Time (US & Canada)")
      if time.wday > 5
        action_date = Time.now.in_time_zone("Eastern Time (US & Canada)").to_date + (8-time.wday).days
      else
        if time.strftime("%H:%M") > "16:30"
          if time.wday == 5
            action_date = Time.now.in_time_zone("Eastern Time (US & Canada)").to_date + 3.days
          else
            action_date = Time.now.in_time_zone("Eastern Time (US & Canada)").to_date + 1.day
          end
        else
          action_date = Time.now.in_time_zone("Eastern Time (US & Canada)").to_date
        end
      end
      @description = action_date.strftime("%Y/%m/%d") + " - " + action
      stock.actions.where(description: @description).first_or_create
      stock.display_item.update(action: @description)
    else
      @description = "IGNORE"
      stock.actions.where(description: @description).first_or_create
      stock.display_item.update(action: @description)
    end

    respond_to do |format|
      format.js { }
    end
  end

  # GET /pages/1
  # GET /pages/1.json
  def show
  end

  # GET /pages/new
  def new
    @page = Page.new
  end
  
  def update_workers
    self.set_workers
    respond_to do |format|
      format.js { }
    end
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
      PortfolioItem.import_pi(params[:file])
      redirect_to root_url, notice: "Portfolio data being processed; this will take about a minute."
    end
  end

  def import_si
    if params[:file].nil?
      redirect_to root_url, alert: "Please select a compatible file to import."
    else
      ScreenItem.import_si(params[:file])
      redirect_to root_url, notice: "Screen data being processed; this will take a minute or two."
    end
  end
  
  def auto_import_si
    GetScreenMechanizeWorker.perform_async
    redirect_to root_url, notice: "Screen data being gathered and processed; this may take a minute or two."
  end
  
  def auto_import_ed
    Stock.get_earnings_by_date(false)
    redirect_to root_url, notice: "Gathering next two weeks of earnings dates; this will take a few seconds."
  end
  
  def update_display
    if Rails.env == "production" && Sidekiq::Stats.new.workers_size > 0
      redirect_to root_url, alert: "Screen or portfolio data are still being processed.  Please try again momentarily."
    else
      SetDisplayItemsWorker.perform_async
      redirect_to root_url, notice: "Updating data for analysis page"
    end
  end
  
  def export_to_excel
    if Rails.env == "production" && Sidekiq::Stats.new.workers_size > 0
      redirect_to root_url, alert: "Data are still being processed.  Please try again momentarily."
    else
      self.create_spreadsheet
    end
  end

  def export_transactions_to_excel
    if Rails.env == "production" && Sidekiq::Stats.new.workers_size > 0
      redirect_to root_url, alert: "Data are still being processed.  Please try again momentarily."
    else
      self.transactions_spreadsheet
    end
  end
  
  def create_spreadsheet
    spreadsheet = Spreadsheet::Workbook.new
    
    page = spreadsheet.create_worksheet :name => "Screen Results"
    
    ####### ROW/CELL FORMATS ########
    header_format = Spreadsheet::Format.new :weight => :bold, :border => :thin, :horizontal_align => :center, :pattern_fg_color => :lime, :pattern => 1, :size => 9, :text_wrap => true, :vertical_align => :top
    default_format = Spreadsheet::Format.new :border => :thin, :horizontal_align => :center, :size => 9, :text_wrap => true, :vertical_align => :top

    # set header
    page.row(0).push "Symbol", "Exchange", "Company", "In Portfolio", "Recommended Action", "Action", "Total Score", "Total Score Percentile", "Dist > 7 or 8", "Market Cap", "Net Stock Issues", "Net Stock Issues Rank", "RelAccruals", "RelAccruals Rank", "NetOpAssetsScaled", "NetOpAssetsScaled Rank", "Assets Growth", "Assets Growth Rank", "InvestToAssets", "InvestToAssets Rank", "52 Week Price", "52 Week Price Rank", "Profit Premium", "Profit Premium Rank", "ROA Quarterly", "ROA Quarterly Rank", "DistTotal2", "DistTotal2 Rank", "Days from Previous Earnings", "Days to Next Earnings", "Last Quarter Revenue", "Classification"
    32.times do |i|
      page.row(0).set_format(i, header_format)
    end
    
    display_items = DisplayItem.all
    screen_items = ScreenItem.all.includes(:stock)
    display_items.each_with_index do |di, i|
      si = screen_items.find_by(:stocks => { :symbol => di.symbol, :exchange => di.exchange })
      page.row(i+1).push di.symbol, di.exchange, di.company, di.in_pf, di.rec_action, di.action, di.total_score, di.total_score_pct, di.dist_status, di.mkt_cap, !si.nil? ? si.net_stock_issues.to_f : "N/A", di.nsi_score, !si.nil? ? si.rel_accruals.to_f : "N/A", di.ra_score, !si.nil? ? si.net_op_assets_scaled.to_f : "N/A", di.noas_score, !si.nil? ? si.assets_growth.to_f : "N/A", di.ag_score, !si.nil? ? si.adj_invest_to_assets.to_f : "N/A", di.aita_score, !si.nil? ? si.l_52_wk_price.to_f : "N/A", di.l52wp_score, !si.nil? ? si.profit_prem.to_f : "N/A", di.pp_score, !si.nil? ? si.roa_q.to_f : "N/A", di.rq_score, !si.nil? ? si.dist_total_2.to_f : "N/A", di.dt2_score, di.prev_ed, di.next_ed, di.lq_revenue, di.classification
    end
    
    summary = StringIO.new
    spreadsheet.write summary
    file = "Screen Summary #{Date.today.strftime("%Y.%m.%d")}.xls"
    send_data summary.string, :filename => "#{file}", :type=>"application/excel", :disposition=>'attachment'
  end
  
  def transactions_spreadsheet
    spreadsheet = Spreadsheet::Workbook.new
    
    page = spreadsheet.create_worksheet :name => "Transaction Log"
    
    ####### ROW/CELL FORMATS ########
    header_format = Spreadsheet::Format.new :weight => :bold, :border => :thin, :horizontal_align => :center, :pattern_fg_color => :lime, :pattern => 1, :size => 9, :text_wrap => true, :vertical_align => :top
    default_format = Spreadsheet::Format.new :border => :thin, :horizontal_align => :center, :size => 9, :text_wrap => true, :vertical_align => :top
    date_format = Spreadsheet::Format.new :number_format => 'YYYY-MM-DD'

    # set headers
    page.row(0).push "Position Information", "", "", "", "", "", "", "", "", "", "", "Acquisition Information", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "Close/Current Information", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""
    page.row(1).push "Symbol", "Exchange", "Company", "Position", "Position Type", "Opt Type", "Opt Strike", "Opt Exp", "Quantity", "In PF", "", "Date Acquired", "Unit Price", "Screen Rec", "Total Score", "Total Score %", "NSI Score", "RA Score", "NOAS Score", "AG Score", "AITA Score", "L52WP Score", "PP Score", "RQ Score", "DT2 Score", "Prev Earnings", "Next Earnings", "Mkt Cap", "Last Q Rev", "", "Date Closed", "Last Price", "Screen Rec", "Total Score", "Total Score %", "NSI Score", "RA Score", "NOAS Score", "AG Score", "AITA Score", "L52WP Score", "PP Score", "RQ Score", "DT2 Score", "Prev Earnings", "Next Earnings", "Mkt Cap", "Last Q Rev"
    48.times do |i|
      page.row(1).set_format(i, header_format)
    end
    
    transaction_items = TransactionItem.where.not(total_score_pct_o: nil)
    transaction_items.each_with_index do |ti, i|
      if ti.active
        page.row(i+2).push ti.symbol, ti.exchange, ti.company, ti.position, ti.pos_type, ti.op_type, ti.op_strike, ti.op_expiration, ti.quantity, ti.active, "", ti.date_acq, ti.paid, ti.rec_action_o, ti.total_score_o, ti.total_score_pct_o, ti.nsi_score_o, ti.ra_score_o, ti.noas_score_o, ti.ag_score_o, ti.aita_score_o, ti.l52wp_score_o, ti.pp_score_o, ti.rq_score_o, ti.dt2_score_o, ti.prev_ed_o, ti.next_ed_o, ti.mkt_cap_o, ti.lq_revenue_o, "", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A"
      else
        page.row(i+2).push ti.symbol, ti.exchange, ti.company, ti.position, ti.pos_type, ti.op_type, ti.op_strike, ti.op_expiration, ti.quantity, ti.active, "", ti.date_acq, ti.paid, ti.rec_action_o, ti.total_score_o, ti.total_score_pct_o, ti.nsi_score_o, ti.ra_score_o, ti.noas_score_o, ti.ag_score_o, ti.aita_score_o, ti.l52wp_score_o, ti.pp_score_o, ti.rq_score_o, ti.dt2_score_o, ti.prev_ed_o, ti.next_ed_o, ti.mkt_cap_o, ti.lq_revenue_o, "", ti.date_sold.strftime("%Y-%m-%d"), ti.last, ti.rec_action_c, ti.total_score_c, ti.total_score_pct_c, ti.nsi_score_c, ti.ra_score_c, ti.noas_score_c, ti.ag_score_c, ti.aita_score_c, ti.l52wp_score_c, ti.pp_score_c, ti.rq_score_c, ti.dt2_score_c, ti.prev_ed_c, ti.next_ed_c, ti.mkt_cap_c, ti.lq_revenue_c
      end
      page.row(i+2).set_format(11, date_format)
      page.row(i+2).set_format(30, date_format) if !ti.active
    end
    
    summary = StringIO.new
    spreadsheet.write summary
    file = "Transactional Summary #{Date.today.strftime("%Y.%m.%d")}.xls"
    send_data summary.string, :filename => "#{file}", :type=>"application/excel", :disposition=>'attachment'
  end
  
  def set_workers
    if Rails.env == "production"
      @worker_hash = {}
      worker_types = ['ImportScreenWorker', 'GetScreenMechanizeWorker', 'ImportPortfolioWorker', 'SetDisplayItemsWorker', 'UpdateEarningsDatesWorker']
      workers = Sidekiq::Workers.new
      worker_classes = workers.map { |process_id, thread_id, work| work['payload']['class'] }
      worker_types.each { |w| @worker_hash[w] = worker_classes.count(w) }
    else
      # populate local hash with dummy data
      @worker_hash = { 'ImportScreenWorker' => 0, 'GetScreenMechanizeWorker' => 1, 'ImportPortfolioWorker' => 2, 'SetDisplayItemsWorker' => 3, 'UpdateEarningsDatesWorker' => 4 } 
    end
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
    
    def set_update_times
      portfolio_items = PortfolioItem.all
      screen_items = ScreenItem.all
      # portfolio items
      @pi_period = portfolio_items.pluck(:set_created_at).uniq.sort.last
      
      # screen items
      @si_period = screen_items.pluck(:set_created_at).uniq.sort.last
      
      # display items
      @di_period = DisplayItem.last.set_created_at
    end
end
