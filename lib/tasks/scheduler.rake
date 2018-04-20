desc "Update Earnings Dates"
task :update_earnings_dates => :environment do
  puts "Spawning workers to update earnings dates..."
  Stock.get_earnings_by_date(false)
  puts "Done spawning workers."
end

desc "Send Update"
task :send_update_emails => :environment do
  updated_at = DisplayItem.last.created_at
  # only send if last update was between 5 and 15 minutes ago
  if updated_at > (Time.now - 15.minutes) && updated_at <= (Time.now - 5.minutes)
    puts "Sending email"
    UpdateMailer.update_email.deliver_now
    puts "Email sent."
  end
end
