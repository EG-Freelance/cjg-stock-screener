web: bundle exec thin start -p $PORT -e $RAILS_ENV
worker: sh -c 'bundle exec sidekiq -e production; phantomjs --webdriver=8001 &'