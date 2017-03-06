class PagesController < ApplicationController
  before_action :set_page, only: [:show, :edit, :update, :destroy]
  before_action :set_update_times, only: [:index, :analysis]

  # GET /pages
  # GET /pages.json
  def index
    @pages = Page.all
  end
  
  def analysis
    if Rails.env == "production" && Sidekiq::Stats.new.workers_size > 0
      redirect_to :back, alert: "Screen or portfolio data are still being compiled, or analysis data are being processed; please try again momentarily."
    end
    #screen item variables and arrays
    si_pool_lg = DisplayItem.where(classification: "large")
    si_pool_sm = DisplayItem.where(classification: "small")
    @si_lg = si_pool_lg.map { |si| [si.symbol, si.exchange, si.company, si.in_pf, si.rec_action, si.action, si.total_score, si.total_score_pct, si.dist_status, si.mkt_cap, si.nsi_score, si.ra_score, si.noas_score, si.ag_score, si.aita_score, si.l52wp_score, si.pp_score, si.rq_score, si.dt2_score, si.prev_ed, si.next_ed, si.lm_revenue] }.sort_by { |si| si[7] }.reverse!
    @si_sm = si_pool_sm.map { |si| [si.symbol, si.exchange, si.company, si.in_pf, si.rec_action, si.action, si.total_score, si.total_score_pct, si.dist_status, si.mkt_cap, si.nsi_score, si.ra_score, si.noas_score, si.ag_score, si.aita_score, si.l52wp_score, si.pp_score, si.rq_score, si.dt2_score, si.prev_ed, si.next_ed, si.lm_revenue] }.sort_by { |si| si[7] }.reverse!
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
    page.row(0).push "Symbol", "Exchange", "Company", "In Portfolio", "Recommended Action", "Action", "Total Score", "Total Score Percentile", "Dist > 7 or 8", "Market Cap", "Net Stock Issues", "Net Stock Issues Rank", "RelAccruals", "RelAccruals Rank", "NetOpAssetsScaled", "NetOpAssetsScaled Rank", "Assets Growth", "Assets Growth Rank", "InvestToAssets", "InvestToAssets Rank", "52 Week Price", "52 Week Price Rank", "Profit Premium", "Profit Premium Rank", "ROA Quarterly", "ROA Quarterly Rank", "DistTotal2", "DistTotal2 Rank", "Days from Previous Earnings", "Days to Next Earnings", "Last Month Revenue", "Classification"
    32.times do |i|
      page.row(0).set_format(i, header_format)
    end
    
    display_items = DisplayItem.all
    screen_items = ScreenItem.all.includes(:stock)
    display_items.each_with_index do |di, i|
      si = screen_items.find_by(:stocks => { :symbol => di.symbol, :exchange => di.exchange })
      page.row(i+1).push di.symbol, di.exchange, di.company, di.in_pf, di.rec_action, di.action, di.total_score, di.total_score_pct, di.dist_status, di.mkt_cap, si.net_stock_issues.to_f, di.nsi_score, si.rel_accruals.to_f, di.ra_score, di.noas_score, si.net_op_assets_scaled.to_f, di.ag_score, si.assets_growth.to_f, di.aita_score, si.adj_invest_to_assets.to_f, di.l52wp_score, si.l_52_wk_price.to_f, di.pp_score, si.profit_prem.to_f, di.rq_score, si.roa_q.to_f, di.dt2_score, si.dist_total_2.to_f, di.prev_ed, di.next_ed, di.lm_revenue, di.classification
    end
    
    summary = StringIO.new
    spreadsheet.write summary
    file = "Screen Summary #{Date.today.strftime("%Y.%m.%d")}.xls"
    send_data summary.string, :filename => "#{file}", :type=>"application/excel", :disposition=>'attachment'
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
