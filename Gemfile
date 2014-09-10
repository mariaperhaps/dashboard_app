source "https://rubygems.org"

ruby "2.1.2"

gem 'sinatra', '1.4.5'
gem 'redis',  '3.1.0'

# only used in development locally
group :development do
  gem 'twitter'
  gem 'httparty'
  gem 'pry'
  gem 'shotgun'
end

group :production do
  gem 'twitter'
  gem 'httparty'
  # gems specific just in the production environment
end

group :test do
  gem 'rspec'
end
