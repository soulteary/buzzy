source "https://rubygems.org"

gem "rails", ">= 8.1.2"

# Assets & front end
gem "importmap-rails"
gem "propshaft"
gem "stimulus-rails"
gem "turbo-rails"

# Deployment and drivers
gem "bootsnap", require: false
gem "kamal", require: false
gem "puma", ">= 5.0"
gem "solid_cable", ">= 3.0"
gem "solid_cache", "~> 1.0"
gem "solid_queue", "~> 1.2"
gem "sqlite3", ">= 2.0"
gem "thruster", require: false
gem "trilogy", "~> 2.9"

# Features
gem "geared_pagination", "~> 1.2"
gem "rqrcode"
gem "redcarpet"
gem "jbuilder"
gem "image_processing", "~> 1.14"
gem "platform_agent"
gem "aws-sdk-s3", require: false
gem "web-push"
gem "net-http-persistent"
gem "zip_kit"
gem "mittens"
gem "useragent", path: "vendor/useragent"

# Operations
gem "autotuner"
gem "mission_control-jobs"
gem "benchmark" # indirect dependency, being removed from Ruby 3.5 stdlib so here to quash warnings

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "debug"
  gem "faker"
  gem "letter_opener"
  gem "rack-mini-profiler"
  gem "rubocop-rails-omakase", require: false
end

group :development, :staging do
  gem "bullet"
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webmock"
  gem "vcr"
  gem "mocha"
end
