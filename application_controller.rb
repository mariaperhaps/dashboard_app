require './helpers/application_helper'

class ApplicationController < Sinatra::Base

  ########################
  # Configuration
  ########################

  configure do
    enable :logging
    enable :method_override
    enable :sessions
    # redis://redistogo:bb0f327db7b826157199cdcdaa80ef3d@barreleye.redistogo.com:11386/
    uri = URI.parse(ENV["REDISTOGO_URL"])
    $redis = Redis.new({:host => uri.host,
                        :port => uri.port,
                        :password => uri.password,
                        :db => 1})

  end

  before do
    logger.info "Request Headers: #{headers}"
    logger.warn "Params: #{params}"
  end

  after do
    logger.info "Response Headers: #{response.headers}"
  end

  #########################
  #API KEYS
  #########################

    TWITTER_CLIENT_KEY = ENV["TWITTER_CLIENT_KEY"]
    TWITTER_CLIENT_SECRET = ENV["TWITTER_SECRET"]
    NYTIMES_API_KEY = ENV["NYTIMES_API_KEY"]
    WEATHER_API_KEY = ENV["WEATHER_API_KEY"]

end
