class UpdateMailer < ApplicationMailer
  default from: 'stock.screener.updates@gmail.com'
  
  def update_email
    DisplayItem.create_xls
    
    attachments["Screen Update #{Date.today.strftime('%F')}.xls"] = File.open('temp.xls', 'rb'){ |f| f.read }

    mail(to: "matt@syniksolutions.com", subject: "Screen Update")
  end
  
  def ohlc_email(email)
    attachments["OHLC output #{Date.today.strftime("%F")}.xls"] = File.open('temp_ohlc.xls', 'rb'){ |f| f.read }
    
    mail(to: email, subject: "OHLC Output")
  end
end
