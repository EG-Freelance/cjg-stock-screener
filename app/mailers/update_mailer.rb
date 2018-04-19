class UpdateMailer < ApplicationMailer
  default from: 'stock.screener.updates@gmail.com'
  
  def update_email
    data = DisplayItem.create_xls
    # spreadsheet_file = StringIO.new
    # data.write(spreadsheet_file)
    # file = Tempfile.new(['temp','.xls'])
    # file.binmode
    # file.write spreadsheet_file.read
    
    # attachments["Screen Update #{Date.today.strftime('%F')}.xls"] = File.open(file, 'rb'){ |f| f.read }
    attachments["Screen Update #{Date.today.strftime('%F')}.xls"] = { content: data, mime_type: Mime::XLS }
    
    mail(to: "erik.w.gibbons@gmail.com", subject: "Screen Update")
  end
end
