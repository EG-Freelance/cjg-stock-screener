web: bundle exec thin start -p $PORT
worker: bundle exec sidekiq -e production -C config/sidekiq.yml