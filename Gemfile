source 'https://rubygems.org'
ruby '2.3.0'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.2.5'
group :development, :test do
  # Use sqlite3 as the database for Active Record
  gem 'sqlite3'
  # use derailed to see memory usage for each gem
  gem 'derailed_benchmarks'
end

group :production do
  # Use pg for heroku db
  gem 'pg'
  gem 'thin'
  # Rails 12 Factor for heroku logging
  gem 'rails_12factor'
end

# use ransack/will_paginate to make listings searchable and paginated
gem 'ransack'
gem 'will_paginate'

# use yajl-ruby to optimize JSON parsing
gem 'yajl-ruby', require: 'yajl/json_gem'

# use mechanize to get screen items
gem 'mechanize'

# use watir and phantomjs to drive the headless browser
# gem 'watir', "~> 6.0"

# use activerecord-import for batch importing
gem 'activerecord-import'

# devise for user authentication
gem 'devise'

# use Roo to import portfolio and screens
gem 'roo'
gem 'roo-xls'

# use simple_form for forms
gem 'simple_form'

# sidekiq and redis for processing and monitoring background jobs
gem 'redis'
gem 'sidekiq'
gem 'sidekiq-failures'
gem 'sidekiq-status'


# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.1.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'
gem 'jquery-ui-rails'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'jquery-turbolinks'
gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Use axlsx to write files to xlsx
# gem 'rubyzip', '~> 1.1.0'
# gem 'axlsx', '2.1.0.pre'
# gem 'axlsx_rails'

# AWS SDK & Paperclip to handle OHLC files
# gem 'paperclip', :git=> 'https://github.com/thoughtbot/paperclip', :ref => '523bd46c768226893f23889079a7aa9c73b57d68'
gem 'aws-sdk', '~> 2.3'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
end