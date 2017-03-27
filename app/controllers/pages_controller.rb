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
    # # total funds available = 2.8M - [non-screen](last * quant) + [screen-close](last * quant)
    # fallen_out = display_items.where(classification: "fallen out").map { |di| di.portfolio_items.map { |pi| pi.last.to_f * pi.quantity unless pi.pos_type == "option" }.compact.sum }.sum
    # if Rails.env == "production"
    #   close_pos = display_items.where('rec_action ~* ?', 'CLOSE').map { |di| di.portfolio_items.map { |pi| pi.last.to_f * pi.quantity unless pi.pos_type == "option" }.compact.sum }.sum
    # else
    #   close_pos = display_items.where('rec_action LIKE ?', 'CLOSE').map { |di| di.portfolio_items.map { |pi| pi.last.to_f * pi.quantity unless pi.pos_type == "option" }.compact.sum }.sum
    # end
    
    # total_funds = 2800000 - fallen_out + close_pos
    # rec_portfolio = display_items.where('rec_action != ? AND rec_action != ? AND classification != ?', 'CLOSE', '(n/a)', 'fallen out')
    
    # mkt_cap_base = rec_portfolio.map { |di| di.mkt_cap }.sum

    if Rails.env == "production" && Sidekiq::Stats.new.workers_size > 0
      redirect_to :back, alert: "Screen or portfolio data are still being compiled, or analysis data are being processed; please try again momentarily."
    end
    #screen item variables and arrays
    si_pool_lg = display_items.where(classification: "large")
    si_pool_sm = display_items.where(classification: "small")
    po_pool = display_items.where(classification: "fallen out")
    @si_lg = si_pool_lg.map { |si| [si.symbol, si.exchange, si.company, si.in_pf, si.rec_action, si.action, si.total_score, si.total_score_pct, si.dist_status, si.mkt_cap, si.nsi_score, si.ra_score, si.noas_score, si.ag_score, si.aita_score, si.l52wp_score, si.pp_score, si.rq_score, si.dt2_score, si.prev_ed, si.next_ed, si.lq_revenue, si.stock.portfolio_items, si.rec_portfolio, si.curr_portfolio, si.net_portfolio] }.sort_by { |si| si[7] }.reverse!
    
    puts "=================#{@si_lg}=============="
    
    @si_sm = si_pool_sm.map { |si| [si.symbol, si.exchange, si.company, si.in_pf, si.rec_action, si.action, si.total_score, si.total_score_pct, si.dist_status, si.mkt_cap, si.nsi_score, si.ra_score, si.noas_score, si.ag_score, si.aita_score, si.l52wp_score, si.pp_score, si.rq_score, si.dt2_score, si.prev_ed, si.next_ed, si.lq_revenue, si.stock.portfolio_items, si.rec_portfolio, si.curr_portfolio, si.net_portfolio] }.sort_by { |si| si[7] }.reverse!
    
    # for development, just replicate lg pool (so there are multiple tabs of data0)
    if Rails.env == "development"
      @si_lg = @si_sm
    end
    @po = po_pool.map { |pi| [pi.symbol, pi.exchange, pi.company, pi.in_pf, pi.rec_action, pi.action, pi.total_score, pi.total_score_pct, pi.dist_status, pi.mkt_cap, pi.nsi_score, pi.ra_score, pi.noas_score, pi.ag_score, pi.aita_score, pi.l52wp_score, pi.pp_score, pi.rq_score, pi.dt2_score, pi.prev_ed, pi.next_ed, pi.lq_revenue, pi.stock.portfolio_items] }.sort_by { |pi| pi[7] }.reverse!
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
        action_date = Date.today + (8-time.wday).days
      else
        if time.strftime("%H:%M") > "16:30"
          if time.wday == 5
            action_date = Date.today + 3.days
          else
            action_date = Date.today + 1.day
          end
        else
          action_date = Date.today
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
    Stock.get_earnings_by_date
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
