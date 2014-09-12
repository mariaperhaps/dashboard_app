require 'redis'
require 'json'
require 'uri'

uri = URI.parse(ENV["REDISTOGO_URL"])
$redis = Redis.new({:host => uri.host,
                    :port => uri.port,
                    :password => uri.password,
                    :db => 1})

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

$redis.set("profile", {:name => "Maria Schettino", :obsession => "Horror", :location => "Brooklyn, NY", :feeds => ["2"]}.to_json)

