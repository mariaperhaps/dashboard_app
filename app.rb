require 'sinatra/base'
require 'open-uri'
require 'twitter'
require 'rss'
require 'pry'


class App < Sinatra::Base

  ########################
  # Configuration
  ########################

  configure do
    enable :logging
    enable :method_override
    enable :sessions


  end

  before do
    logger.info "Request Headers: #{headers}"
    logger.warn "Params: #{params}"
  end

  after do
    logger.info "Response Headers: #{response.headers}"
  end

  ########################
  # Routes
  ########################

  get('/') do
    render(:erb, :index)
  end

  get('/twitterfeed') do
    client = Twitter::REST::Client.new do |config|
    config.consumer_key    = "UMSX6UsfO7baEVnlTMpnBm59K"
    config.consumer_secret = "wbEJLg2sLMB6A1Ql8GKypriTW0HJ9vrGbNq6zhBMBxQl1YfiBJ"
    end

    @tweets = client.search("horror", :result_type => "recent").take(10).collect do |tweet|
        "#{tweet.user.screen_name}: #{tweet.text}"
    end
    render(:erb, :twitterfeed)
  end

  get('/newyorktimesfeed') do
     url = 'http://rss.nytimes.com/services/xml/rss/nyt/Movies.xml'
     open(url) do |rss|
     @feed = RSS::Parser.parse(rss)
   end
     render(:erb, :newyorktimesfeed)
  end

end

