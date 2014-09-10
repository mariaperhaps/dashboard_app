require 'sinatra/base'
require 'open-uri'
require 'twitter'
require 'httparty'
require 'rss'

require 'redis'
require 'json'
require 'uri'


class App < Sinatra::Base

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
                        :password => uri.password})


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

  # feeds INDEX
  get('/feeds') do
    @feeds = $redis.keys("*feeds*").map do |key|
      JSON.parse($redis.get(key))
    end

    render(:erb, :"feeds/index")
  end

  # feeds SHOW
  get('/feeds/:id') do

    @feed    = JSON.parse($redis.get("feeds:#{params["id"]}"))
    @entries = get_entries(@feed)
    render(:erb, :"feeds/show")
  end

get('/feeds/search/:id') do
  @feed    = JSON.parse($redis.get("feeds:#{params["feed_id"]}"))
  case @feed["name"]
    when "Twitter"
      @entries = entries_from_twitter_with(create_twitter_client, params["search"])
    when "Weather"
      @entries = entry_from_weather_for(params["search"])
    when "NYTimes"
      @entries = entries_from_nytimes_for(params["search"])
  end
  render(:erb, :"feeds/show")
end

  # profile SHOW
  get('/profile') do
    # set the @profile instance!
    profile = current_profile
    @feeds  = current_profile["feeds"].map {|feed_id| JSON.parse($redis.get("feeds:#{feed_id}"))}

    render(:erb, :"profiles/show")
  end

  # profile UPDATE
  put('/profile') do
    temp_profile = current_profile
    temp_profile["feeds"] << params["feed_id"]
    $redis.set("profile", temp_profile.to_json)

    redirect to('/profile')
  end

  delete('/profile') do
    temp_profile = current_profile
    temp_profile["feeds"].delete(params["feed_id"])
    $redis.set("profile",temp_profile.to_json)
    redirect to('/profile')
  end

  # get('/rss_feeds') do
  #     #NYTimes Movie Reviews RSS

  #     url = 'http://rss.nytimes.com/services/xml/rss/nyt/Movies.xml'
  #      open(url) do |rss|
  #      @feed = RSS::Parser.parse(rss)
  #  end
  #   render(:erb, :rss)
  # end




   #method for getting model from redis
   def get_model(redis_id)
     model = JSON.parse($redis.get(redis_id))
     model["id"] = redis_id
     model
    end

    #method for adding a feed
    def add_feed(feed,redis_key)
      number = $redis.keys("*#{redis_key}*").count
      key = "#{redis_key}:#{number + 1}"
      $redis.set(key, feed.to_json)
    end

  # def get_search_entries(feed)
  #   case feed["name"]
  #   when "Twitter"
  #     entries = entries_from_twitter_with(create_twitter_client, "params[:search]")
  #   when "Weather"
  #     entries = entry_from_weather_for("params[:search]")
  #   when "NYTimes"
  #     entries = entries_from_nytimes_for("params[:search]")
  #   end
  # end



  def get_entries(feed)
    case feed["name"]
    when "Twitter"
      entries = entries_from_twitter_with(create_twitter_client, current_profile["obsession"])
    when "Weather"
      entries = entry_from_weather_for(current_profile["location"])
    when "NYTimes"
      entries = entries_from_nytimes_for(current_profile["obsession"])
    end
  end

  #######################
  # Access User Profile!
  #######################

  # a really fun pattern!
  def current_profile
    @profile ||= JSON.parse($redis.get("profile"))
  end

  def current_profile_has(feed)
    # binding.pry
    current_profile["feeds"].include?(feed["id"].to_s)
  end

  #######################
  # Feed Parsing Library
  #######################

  def create_twitter_client
    client = Twitter::REST::Client.new do |config|
      config.consumer_key    = "UMSX6UsfO7baEVnlTMpnBm59K"
      config.consumer_secret = "wbEJLg2sLMB6A1Ql8GKypriTW0HJ9vrGbNq6zhBMBxQl1YfiBJ"
    end
  end

  def entries_from_twitter_with(client, term)
    entries = client.search(term, :result_type => "recent").take(10).collect do |tweet|
       {content: "#{tweet.user.screen_name}: #{tweet.text}", url: "#{tweet.url}" }
    end
  end

  def entries_from_nytimes_for(term)
    response = HTTParty.get("http://api.nytimes.com/svc/search/v2/articlesearch.json?q=#{term}&page=1&sort=newest&api-key=2ef91dbc7dbac505b10c9c14faed9c7a:0:69763254")
    entries = response["response"]["docs"]
  end

  def entry_from_weather_for(location)
    state = location.split(",")[1].gsub(" ","")
    city = location.split(",")[0]
    response = HTTParty.get("http://api.wunderground.com/api/0abb4ae8d46481a9/geolookup/conditions/q/#{state}/#{city}.json")
    location = response['location']['city']
    temp     = response['current_observation']['temp_f']
    link    = response["current_observation"]["forecast_url"]
    entry = {text: "The current temp in #{location} is #{temp} degrees", link: link}
  end

end
