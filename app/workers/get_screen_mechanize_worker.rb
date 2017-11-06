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
    response = agent.post("https://stock.screener.co/screenerinclude.php?token=#{token}&asset=stocks&type=loadScreen&name=Mispricing8d")
    # load data from screen
    # set header row
    results = [["Symbol", "Company Name", "NetStockIssues", "RelAccruals", "NetOpAssets Scaled", "Assets Growth", "InvestToAssets", "Price-52 week price percent change", "Market capitalization", "Gross Profit Premium", "ROA Quarterly", "DistTotal2", "Revenue-Last Quarter", "Price to Book Current", "Enterprise Value/Free Op Cash Flows", "Price to Book LYQ"]]
    conditions = "Exchange%20Country%7C=%7C%22USA%22%7C1%7C0%7C%7CPrice-200%20Day%20Average%7C%3E=%7C5%7C3%7C0%7C%7CNetStockIssues%7C%3E=%7C0%7C4%7C0%7C%7CRelAccruals%7C%3E%7C-1000000000000%7C4%7C0%7C%7CNetOpAssets%20Scaled%7C%3E%7C-1000000000000000%7C4%7C0%7C%7CAssets%20Growth%7C%3E%7C0%7C4%7C0%7C%7CInvestToAssets%7C%3E%7C-1000000000000%7C4%7C1%7C%7CPrice-52%20week%20price%20percent%20change%7C%3E=%7C-10000000000000000%7C3%7C0%7C%7CMarket%20capitalization%7C%3E%7C0%7C3%7C0%7C%7CGross%20Profit%20Premium%7C%3E=%7C-100000000%7C3%7C0%7C%7CROA%20Quarterly%7C%3E%7C-1000000000000%7C4%7C0%7C%7CSector%7C!=%7C%22Financials%22%7C1%7C0%7C%7CIndustry%7C!=%7C%22Integrated%20Oil%20%2B%20Gas%22%7C1%7C0%7C%7CIndustry%7C!=%7C%22Oil%20%2B%20Gas%20Drilling%22%7C1%7C0%7C%7CIndustry%7C!=%7C%22Oil%20%2B%20Gas%20Exploration%20and%20Production%22%7C1%7C0%7C%7CIndustry%7C!=%7C%22Commercial%20REITs%22%7C1%7C0%7C%7CIndustry%7C!=%7C%22Electric%20Utilities%22%7C1%7C0%7C%7CIndustry%7C!=%7C%22Natural%20Gas%20Utilities%22%7C1%7C0%7C%7CIndustry%7C!=%7C%22Water%20Utilities%22%7C1%7C0%7C%7CIndustry%7C!=%7C%22Banks%22%7C1%7C0%7C%7CIndustry%7C!=%7C%22Oil%20Related%20Services%20and%20Equipment%22%7C1%7C0%7C%7CIndustry%7C!=%7C%22Gold%22%7C1%7C0%7C%7CIndustry%7C!=%7C%22Uranium%22%7C1%7C0%7C%7CIndustry%7C!=%7C%22Precious%20Metals%20%2B%20Minerals%22%7C1%7C0%7C%7CIndustry%7C!=%7C%22Coal%22%7C1%7C0%7C%7CIndustry%7C!=%7C%22Multiline%20Utilities%22%7C1%7C0%7C%7CDistTOTAL2%7C%3E%7C-100000000%7C3%7C0"
    fields1 = "Symbol%7CCompany%20Name%7CNetStockIssues%7CRelAccruals%7CNetOpAssets%20Scaled%7CAssets%20Growth%7CInvestToAssets%7CPrice-52%20week%20price%20percent%20change%7CMarket%20capitalization%7CGross%20Profit%20Premium%7CROA%20Quarterly%7CDistTOTAL2"
    fields2 = "Symbol%7CCompany%20Name%7CNetStockIssues%7CRelAccruals%7CNetOpAssets%20Scaled%7CAssets%20Growth%7CInvestToAssets%7CPrice-52%20week%20price%20percent%20change%7CRevenue-most%20recent%20quarter%7CCurrent%20Price%20to%20Book,%20Total%20Equity-LFI%7CHistoric%20Enterprise%20Value/Free%20Operating%20Cash%20Flow%20Excluding%20Dividends-TTM%7CPrice%20to%20Book-most%20recent%20quarter-1%20year%20ago"
    counter = 0
    loop do 
      start_number = counter * 50      
      # two posts for each page to pull in revenue data as well (screen limits to 12 response variables, and we need 13)
      response = agent.post("https://stock.screener.co/screenerinclude.php?token=#{token}&asset=stocks&type=calcStocks&conditions=#{conditions}&fields=#{fields1}&orderVar=Gross%20Profit%20Premium&orderDir=ASC&start=#{start_number}&limit=50&csv=0&markets=")
      response2 = agent.post("https://stock.screener.co/screenerinclude.php?token=#{token}&asset=stocks&type=calcStocks&conditions=#{conditions}&fields=#{fields2}&orderVar=Gross%20Profit%20Premium&orderDir=ASC&start=#{start_number}&limit=50&csv=0&markets=")
      response_raw = response.content
      response_raw2 = response2.content
      
      # break once we are past the useable data
      break if response_raw == ""
      
      # each company is separated by a double pipe ||
      response_array = response_raw.split("||")
      response_array2 = response_raw2.split("||")
      
      # each entry in a company row is separated by a single pipe | (we're creating a nested array here)
      entries = response_array.map { |r| r.split("|") }
      entries2 = response_array2.map { |r| r.split("|") }
      results += entries.each_with_index { |e,i| e.push(entries2[i][9..11]).flatten! }
 
      counter += 1
    end
    ScreenItem.auto_import(results)
  end
end