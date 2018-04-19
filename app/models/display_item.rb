class DisplayItem < ActiveRecord::Base
  has_one :stock
  has_many :portfolio_items, :through => :stock
  has_many :screen_items, :through => :stock
  
  def self.create_xls
    spreadsheet = Spreadsheet::Workbook.new
    
    page = spreadsheet.create_worksheet :name => "Screen Results"
    
    ####### ROW/CELL FORMATS ########
    header_format = Spreadsheet::Format.new :weight => :bold, :border => :thin, :horizontal_align => :center, :pattern_fg_color => :lime, :pattern => 1, :size => 9, :text_wrap => true, :vertical_align => :top
    # default_format = Spreadsheet::Format.new :border => :thin, :horizontal_align => :center, :size => 9, :text_wrap => true, :vertical_align => :top
    # bold_format = Spreadsheet::Format.new :weight => :bold

    # set header
    page.row(0).push "Symbol", "Exchange", "Company", "In PF (L) Rec", "In PF (S) Rec", "Not in PF Rec", "Total Score Percentile", "Market Cap"
    8.times do |i|
      page.row(0).set_format(i, header_format)
    end
    
    display_items = DisplayItem.all.includes(:stock => :screen_items).where.not(:screen_items => { :id => nil })
    
    lg_med_p_to_b = MathStuff.median(display_items.where(classification: "large").collect(&:p_to_b_curr).compact)
    lg_med_ev_to_fcf = MathStuff.median(display_items.where(classification: "large").collect(&:ent_val_ov_focf).compact)
    sm_med_p_to_b = MathStuff.median(display_items.where(classification: "small").collect(&:p_to_b_curr).compact)
    sm_med_ev_to_fcf = MathStuff.median(display_items.where(classification: "small").collect(&:ent_val_ov_focf).compact)

    
    rec_earn = 180
    
    display_items.each_with_index do |di, i|
      si = di.stock.screen_items.first
      # set earnings_date related vars
      prev_ed = si.stock.earnings_dates.where('date < ?', Date.today)
      prev_ed.empty? ? si_pe = "N/A" : si_pe = (Date.today - prev_ed.last.date).to_i

      # set actions for each scenario
      si_pe == "N/A" ? prev_earn = 365 : prev_earn = si_pe
      
      # case when in pf, short
      case
      # in top 10%
      when di.total_score_pct >= 0.9 && prev_earn <= rec_earn && di.dt2_score < 8
        inpf_shrt = "CLOSE AND BUY"
      # when any current short position has DistTotal2 < 9
      when di.dt2_score < 9
        inpf_shrt = "CLOSE"
      # in bottom 20%
      when di.total_score_pct <= 0.2 || prev_earn > rec_earn
        inpf_shrt = "HOLD"
      # in middle 75%
      else
        inpf_shrt = "CLOSE"
      end
      
      # case when in pf, long
      case
      # in bottom 10%
      when di.total_score_pct <= 0.1 && prev_earn <= rec_earn && di.dt2_score > 8
        inpf_lng = "CLOSE AND SHORT"
      # when any current long position has DistTotal2 > 7
      when di.dt2_score > 7
        inpf_lng = "CLOSE"
      # in top 20%
      when di.total_score_pct >= 0.8 || prev_earn > rec_earn
        inpf_lng = "HOLD"
      # in middle 75%
      else
        inpf_lng = "CLOSE"
      end
      
      # case when not in pf
      case
      # if in top 10%
      when di.total_score_pct >= 0.9 && di.dt2_score < 8
        nopf = "BUY"
      # if in bottom 10%
      when di.total_score_pct <= 0.1 && di.dt2_score > 8
        nopf = "SHORT"
      # if in middle 80%
      else
        nopf = "(n/a)"
      end

      # set strong/add to large long
      if di.classification == "large"
        if !di.p_to_b_curr.nil? && !di.ent_val_ov_focf.nil? && di.p_to_b_curr < lg_med_p_to_b && di.ent_val_ov_focf < lg_med_ev_to_fcf
          inpf_shrt = inpf_shrt + " (STRONG)" if inpf_shrt["BUY"]
          inpf_lng = inpf_lng + " (ADD)" if inpf_lng["HOLD"]
          nopf = nopf + " (STRONG)" if nopf["BUY"]
        end
        # set strong/add to large short
        if !di.p_to_b_curr.nil? && !di.ent_val_ov_focf.nil? && di.p_to_b_curr > lg_med_p_to_b && di.ent_val_ov_focf > lg_med_ev_to_fcf
          inpf_lng = inpf_lng + " (STRONG)" if inpf_lng["SHORT"]
          inpf_shrt = inpf_shrt + " (ADD)" if inpf_shrt["HOLD"]
          nopf = nopf + " (STRONG)" if nopf["SHORT"]
        end
      else
        # set strong/add to small long
        if !di.p_to_b_curr.nil? && !di.ent_val_ov_focf.nil? && di.p_to_b_curr < sm_med_p_to_b && di.ent_val_ov_focf < sm_med_ev_to_fcf
          inpf_shrt = inpf_shrt + " (STRONG)" if inpf_shrt["BUY"]
          inpf_lng = inpf_lng + " (ADD)" if inpf_lng["HOLD"]
          nopf = nopf + " (STRONG)" if nopf["BUY"]
        end
        # set strong/add to small short
        if !di.p_to_b_curr.nil? && !di.ent_val_ov_focf.nil? && di.p_to_b_curr > sm_med_p_to_b && di.ent_val_ov_focf > sm_med_ev_to_fcf
          inpf_lng = inpf_lng + " (STRONG)" if inpf_lng["SHORT"]
          inpf_shrt = inpf_shrt + " (ADD)" if inpf_shrt["HOLD"]
          nopf = nopf + " (STRONG)" if nopf["SHORT"]
        end
      end

      page.row(i+1).push di.symbol, di.exchange, di.company, inpf_lng, inpf_shrt, nopf, di.total_score_pct, di.mkt_cap
    end

    # summary = StringIO.new
    spreadsheet.write 'temp.xls'
    # file = "Screen Summary #{Date.today.strftime("%Y.%m.%d")}.xls"
    return summary
  end
end