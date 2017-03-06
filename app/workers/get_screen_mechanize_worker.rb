# Worker for getting screen CSV
class GetScreenMechanizeWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'high', unique: :until_executed
  
  def perform
  	    
    # initialize random user agent (e.g. randomly look like linux chrome, mac safari, windows explorer, etc.)
    agent = Mechanize.new
    agent.robots = false
    agent.user_agent_alias = (Mechanize::AGENT_ALIASES.keys - ['Mechanize']).sample 
  
    # log in	
    response = agent.post('https://stock.screener.co/screenerinclude.php?user=erikwgibbons&pass=9902screener')
    token = response.content
    
    # get date
    response = agent.post('https://stock.screener.co/subscribe/getdate.php?username=erikwgibbons')
    
    # load screen info
    response = agent.post("https://stock.screener.co/screenerinclude.php?token=#{token}&asset=stocks&type=loadScreen&name=Mispricing8")
    
    # load data from screen
    # set header row
    results = [["Symbol", "Company Name", "NetStockIssues", "RelAccruals", "NetOpAssets Scaled", "Assets Growth", "InvestToAssets", "Price-52 week price percent change", "Market capitalization", "Gross Profit Premium", "ROA Quarterly", "DistTotal2"]]
    counter = 0
    loop do 
      start_number = counter * 50
      response = agent.post("https://stock.screener.co/screenerinclude.php?token=#{token}&asset=stocks&type=calcStocks&conditions=Exchange%20Country%7C=%7C%22USA%22%7C1%7C0%7C%7CPrice-200%20Day%20Average%7C%3E=%7C5%7C3%7C0%7C%7CNetStockIssues%7C%3E=%7C0%7C4%7C0%7C%7CRelAccruals%7C%3E%7C-1000000000000%7C4%7C0%7C%7CNetOpAssets%20Scaled%7C%3E%7C-1000000000000000%7C4%7C0%7C%7CAssets%20Growth%7C%3E%7C0%7C4%7C0%7C%7CInvestToAssets%7C%3E%7C-1000000000000%7C4%7C1%7C%7CPrice-52%20week%20price%20percent%20change%7C%3E=%7C-10000000000000000%7C3%7C0%7C%7CMarket%20capitalization%7C%3E%7C0%7C3%7C0%7C%7CGross%20Profit%20Premium%7C%3E=%7C0%7C3%7C1%7C%7CROA%20Quarterly%7C%3E%7C-1000000000000%7C4%7C0&fields=Symbol%7CCompany%20Name%7CNetStockIssues%7CRelAccruals%7CNetOpAssets%20Scaled%7CAssets%20Growth%7CInvestToAssets%7CPrice-52%20week%20price%20percent%20change%7CMarket%20capitalization%7CGross%20Profit%20Premium%7CROA%20Quarterly%7CDistTOTAL2&orderVar=RelAccruals&orderDir=ASC&start=#{start_number}&limit=50&csv=0&markets=")
      response_raw = response.content
      
      # break once we are past the useable data
      break if response_raw == ""
      
      # each company is separated by a double pipe ||
      response_array = response_raw.split("||")
      
      # each entry in a company row is separated by a single pipe | (we're creating a nested array here)
      results += response_array.map { |r| r.split("|") }
 
      counter += 1
    end
    ScreenItem.auto_import(results)
  end
end