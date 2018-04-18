class UpdateMailer < ApplicationMailer
	default from: 'stock.screener.updates@gmail.com'
	
	def update_email
		data = DisplayItem.create_xls
		spreadsheet_file = StringIO.new
		data.write(spreadsheet_file)
		attachments["Screen Update #{Date.today.strftime('%F')}.xls"] = File.open(spreadsheet_file, 'rb'){ |f| f.read }
		
		mail(to: "erik.w.gibbons@gmail.com", subject: "Screen Update")
	end
end
