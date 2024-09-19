source "https://rubygems.org"
ruby file: ".ruby-version"

gem "rails", github: "rails/rails", branch: "main"

# Assets & front end
gem "importmap-rails"
gem "propshaft"
gem "stimulus-rails"
gem "turbo-rails"

# Deployment and drivers
gem "bootsnap", require: false
gem "puma", ">= 5.0"
gem "sqlite3", ">= 2.0"

# Features
gem "bcrypt", "~> 3.1.7"
gem "rqrcode"

group :development, :test do
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
