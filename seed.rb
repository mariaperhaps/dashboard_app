require 'redis'
require 'json'
require 'uri'

uri = URI.parse(ENV["REDISTOGO_URL"])
$redis = Redis.new({:host => uri.host,
                    :port => uri.port,
                    :password => uri.password})

$redis.flushdb

# Create a counter to track indexes
$redis.set("feed:index", 0)

# Increment counter and add new feed
id = $redis.incr("feed:index")
$redis.set("feeds:#{id}", {:id => id, :name => "Twitter", :type => :gem_api}.to_json)
id = $redis.incr("feed:index")
$redis.set("feeds:#{id}", {:id => id, :name => "NYTimes", :type => :api, :url => ''}.to_json)
id = $redis.incr("feed:index")
$redis.set("feeds:#{id}", {:id => id, :name => "Weather", :type => :api, :url => ''}.to_json)

$redis.set("profile", {:name => "Maria Schettino", :obsession => "Horror", :location => "Brooklyn, NY"}.to_json)

# twitter = [
#   {
#    "name" => "Twitter",
#    "type" => "api",
#    "search_term" => "horror"
#    }
# ]
#
# nytimes = [{
#     "name" => "NYTimes",
#     "type" => "api",
#     "search_term" => "horror"
# }
# ]
#
# weather = [{
#   "name" => "Weather Underground",
#   "type" => "api",
#   "search_term" => "Brooklyn, NY"
# }
# ]

# twitter.each_with_index do |feed, index|
#   $redis.set("twitter:#{index + 1}", feed.to_json)
# end
#
# nytimes.each_with_index do |feed, index|
#   $redis.set("nytimes:#{index + 1}", feed.to_json)
# end
#
# weather.each_with_index do |feed, index|
#   $redis.set("weather:#{index + 1}", feed.to_json)
# end
