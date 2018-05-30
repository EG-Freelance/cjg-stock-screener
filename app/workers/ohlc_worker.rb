# Worker for getting screen CSV
class OhlcWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'high', unique: :until_executed
  
  def perform(s_array, email)
    # create output workbook
    output = Spreadsheet::Workbook.new
    
    # name tab
    page = output.create_worksheet :name => "OHLC Log"

    # set header format
    header_format = Spreadsheet::Format.new :weight => :bold, :border => :thin, :horizontal_align => :center, :pattern_fg_color => :lime, :pattern => 1, :size => 9, :text_wrap => true, :vertical_align => :top

    # set headers
    page.row(0).push "Symbol", "Date", "Open", "High", "Low", "Close"
    6.times do |i|
      page.row(0).set_format(i, header_format)
    end
    
    # set agent
    agent = Mechanize.new
    
    # remove unnecessary header 
    s_array = s_array[1..-1]
    
    # separate rows with populated data [ [empty_data], [populated_data] ]
    # part = s_array.partition { |s| s[2].nil? }
    
    # get unique stock symbols (except where data are already provided)
    # uniq_sym = part[0].map { |s| s[0] }.uniq
    
    uniq_sym = s_array.map { |s| s[0] }.uniq
    uniq_sym.delete_if { |s| s.match(/\./) }
    
    # create OHLC data container
    # ohlc_hash = {}
    
    # loop params
    r = 1
    loop_start = Time.now - 1.second
    loop_end = Time.now - 1.second
    
    puts "Populating data and writing to output..."
    # populate data
    uniq_sym.each_with_index do |s,i|
      if i % 250 == 0
        agent.get("http://cjg-stock-screener.herokuapp.com/ohlc")
      end
      retries = 0
      begin
        # evaluate to make sure at least a second has passed since the last response request
        loop_end = Time.now
        loop_diff = loop_end - loop_start
        if loop_diff < 1
          sleep(1-loop_diff)
        end
          
        response = agent.get("https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=#{s}&apikey=#{ENV['AA_KEY']}")
        loop_start = Time.now
        resp = JSON.parse(response.body)
        if !resp["Information"].nil?
          raise
        end
        
        ohlc_hash = resp
        
        s_items = s_array.select { |sa| sa[0] == s }
        
        s_items.each do |si|
          # write data to output spreadsheet
          if si[2].nil?
            # skip if problem pulling data
            if !ohlc_hash["Information"].nil?
              page.row(r).push si[0], si[1], "API called too fast", "API called too fast", "API called too fast", "API called too fast"
            end
            if ohlc_hash['Time Series (Daily)'][si[1]].nil?
              page.row(r).push si[0], si[1], "N/A (no data)", "N/A (no data)", "N/A (no data)", "N/A (no data)"
            else
              page.row(r).push si[0], si[1], ohlc_hash['Time Series (Daily)'][si[1]]['1. open'], ohlc_hash['Time Series (Daily)'][si[1]]['2. high'], ohlc_hash['Time Series (Daily)'][si[1]]['3. low'], ohlc_hash['Time Series (Daily)'][si[1]]['4. close']
            end
          else
            page.row(r).push si[0], si[1], si[2], si[3], si[4], si[5]
          end
          r += 1
        end
        
        puts "Succeeded with #{s}"
      rescue
        if retries < 100
          puts "Failed #{s}, try ##{retries + 1}"
          retries += 1
          sleep(4)
          retry
        else
          next
        end
      end
    end

    puts "Writing out and uploading output to S3..."
    output.write ('temp_ohlc.xls')
    # connect to S3
    s3 = Aws::S3::Resource.new({region: ENV['AWS_REGION'], access_key_id: ENV["AWS_ACCESS_KEY_ID"], secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]})
    # set target object
    obj = s3.bucket(ENV['S3_BUCKET']).object('Screener OHLC/ohlc output.xls')
    # upload file
    obj.upload_file('temp_ohlc.xls')
    
    # get presigned link
    signer = Aws::S3::Presigner.new
    # url expires in 12 hours
    url = signer.presigned_url(:get_object, bucket: ENV["S3_BUCKET"], key: 'Screener OHLC/ohlc output.xls', expires_in: 43200)
    UpdateMailer.ohlc_email(email, url).deliver_now
    puts "Finished creating and sending OHLC update!"
  end
end