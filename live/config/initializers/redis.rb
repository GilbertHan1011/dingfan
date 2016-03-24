require "redis"
require "redis-namespace"


# redis instance used to store common data
$redis_amazon = Redis.new(:host => "10.160.40.193", :port => 6380, :driver => :hiredis, :timeout => 0.12)

# cache users data @chelsea[ 115.29.175.119 ]
$redis_berlin = Redis.new(:host => "10.161.166.93", :port => 6379, :driver => :hiredis, :timeout => 0.12)