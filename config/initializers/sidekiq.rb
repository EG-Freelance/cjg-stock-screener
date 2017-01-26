# if Rails.env.production?

#   Sidekiq.configure_client do |config|
#     config.redis = { url: ENV['REDISCLOUD_URL'], size: 2 }
#   end

#   Sidekiq.configure_server do |config|
#     config.redis = { url: ENV['REDISCLOUD_URL'], size: 20 }

#     Rails.application.config.after_initialize do
#       Rails.logger.info("DB Connection Pool size for Sidekiq Server before disconnect is: #{ActiveRecord::Base.connection.pool.instance_variable_get('@size')}")
#       ActiveRecord::Base.connection_pool.disconnect!

#       ActiveSupport.on_load(:active_record) do
#         config = Rails.application.config.database_configuration[Rails.env]
#         config['reaping_frequency'] = ENV['DATABASE_REAP_FREQ'] || 10 # seconds
#         # config['pool'] = ENV['WORKER_DB_POOL_SIZE'] || Sidekiq.options[:concurrency]
#         config['pool'] = 16
#         ActiveRecord::Base.establish_connection(config)

#         Rails.logger.info("DB Connection Pool size for Sidekiq Server is now: #{ActiveRecord::Base.connection.pool.instance_variable_get('@size')}")
#       end
#     end
#   end

# end  

ENV["REDISCLOUD_URL"] ||= "redis://localhost:6379"

Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDISCLOUD_URL"] }

  database_url = ENV['DATABASE_URL']
  if database_url
    ENV['DATABASE_URL'] = "#{database_url}?pool=30"
    ActiveRecord::Base.establish_connection
  end

end


Sidekiq.configure_client do |config|
  config.redis = { url: ENV["REDISCLOUD_URL"] }
end