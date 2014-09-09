require 'sinatra/base'
require 'open-uri'
require 'twitter'
require 'httparty'
require 'rss'
require 'pry'
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

  get('/feeds') do
    @feeds = $redis.keys("*feeds*").map do |key|
      JSON.parse($redis.get(key))
    end

    render(:erb, :"feeds/index")
  end

  get('/feeds/:id') do
    @feed   = JSON.parse($redis.get("feeds:#{params["id"]}"))

    case @feed["name"]
    when "Twitter"
      @entries = entries_from_twitter_with(create_twitter_client, current_profile["obsession"])
    when "Weather"
      @entries = entry_from_weather_for(current_profile["location"])
    when "NYTimes"
      @entries = entries_from_nytimes_for(current_profile["location"])
    end

    render(:erb, :"feeds/show")
  end

  get('/profile') do
    current_profile
    render(:erb, :"profiles/show")
  end

  get('/weather/:id') do
    key = "weather:#{params[:id]}"
    @weather_index = $redis.get(key)
    render(:erb, :feed_id)
  end

  get('/rss_feeds') do
      #NYTimes Movie Reviews RSS

      url = 'http://rss.nytimes.com/services/xml/rss/nyt/Movies.xml'
       open(url) do |rss|
       @feed = RSS::Parser.parse(rss)
   end
    render(:erb, :rss)
  end

  post('/feeds/search') do
    #Weather
    if params[:searchweather]
      state = params[:searchweather].split(",")[1].gsub(" ","")
      city = params[:searchweather].split(",")[0]
      response = HTTParty.get("http://api.wunderground.com/api/0abb4ae8d46481a9/geolookup/conditions/q/#{state}/#{city}.json")

      location = response['location']['city']
      temp = response['current_observation']['temp_f']
      @weather = "The current temp in #{location} is #{temp}"

      add_weather = {"name" => "Weather",
                     "type" => "api",
                     "search_term" => params[:searchweather]
                     }

              add_feed(add_weather, "weather")
              redirect('/feeds')

    end
    render(:erb, :feeds)

    #Twitter
    if params[:searchtwitter]
      client = Twitter::REST::Client.new do |config|
      config.consumer_key    = "UMSX6UsfO7baEVnlTMpnBm59K"
      config.consumer_secret = "wbEJLg2sLMB6A1Ql8GKypriTW0HJ9vrGbNq6zhBMBxQl1YfiBJ"
    end
      @tweets = client.search(params[:searchtwitter], :result_type => "recent").take(10).collect do |tweet|
          { content: "#{tweet.user.screen_name}: #{tweet.text}", url: "#{tweet.url}" }
          twit_search = {"name" => "Twitter",
                         "type" => "api",
                         "search_term" => params[:searchtwitter]
                       }

            add_feed(twit_search,"twitter")

      redirect('/feeds')

    end
    render(:erb, :feeds)
  end

    #NYTIMES API
    if params[:searchnytimes]
      search = params[:searchnytimes]
      response = HTTParty.get("http://api.nytimes.com/svc/search/v2/articlesearch.json?q=#{search}&page=1&sort=newest&api-key=2ef91dbc7dbac505b10c9c14faed9c7a:0:69763254")
      @nytimesarray = response["response"]["docs"]
      nyt_search = {"name" => "NYTimes",
                    "type" => "api",
                    "search_term" => params[:searchnytimes]
                   }

                  add_feed(nyt_search,"nytimes")
            redirect('/feeds')

    end
      render(:erb, :feeds)
  end

   get('/profile') do
    # @myfeeds =[]
    # $redis.keys("*feed*").each do |key|
    #   @myfeeds << get_model(key)
    # end
    render(:erb, :profile)
   end

   post('/profile') do

   end


   get('/profile/edit') do
    render(:erb,:profile_edit)
   end


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


   # add weather to profile
   #  post('/weather') do
   #   weather_feed =  {
   #    "name" => "Weather Underground",
   #    "value" => params[:weather]
   #  }
   #    add_feed(weather_feed)
   #    logger.info @myfeeds
   #    redirect('/profile')
   # end

   #add twitter to profile
   #  post('/twitter') do

   #  twitter_feed = {
   #    "name" => "Twitter",
   #    "value" => params[:twitter]
   #  }
   #  add_feed(twitter_feed)
   #  logger.info @myfeeds
   #  redirect('/profile')
   # end








# def get_weather(city, state)
#   response = HTTParty.get("http://api.wunderground.com/api/0abb4ae8d46481a9/geolookup/conditions/q/#{state}/#{city}.json")
#   c = response['location']['city']
#   s = response['location']['state']
#   t = ['current_observation']['temp_f']
#   puts "Current temperature in #{c}, #{s} is: #{t}"
# end

  #######################
  # Access User Profile!
  #######################

  # a really fun pattern!
  def current_profile
    @profile ||= JSON.parse($redis.get("profile"))
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
