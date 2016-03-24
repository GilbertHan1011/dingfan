

# 32 redis instances
$redis_nodes = {
  :redis_1 => "redis://10.171.228.17:6381", #hades
  
  :redis_2 => "redis://10.161.146.104:6380",
  
  :redis_4 => "redis://10.168.26.54:6382", #dragon

  :redis_5 => "redis://10.168.26.54:6383", #dragon
  
  :redis_6 => "redis://10.168.26.54:6384", #dragon
  
  :redis_8 => "redis://10.168.26.54:6381", #dragon
  
  :redis_9 => "redis://10.171.247.15:6382", #tortoise
  
  :redis_10 => "redis://10.171.247.15:6383", #tortoise
  
  :redis_11 => "redis://10.171.247.15:6380",
  
  :redis_12 => "redis://10.168.35.22:6384",  #mouse
  
  :redis_14 => "redis://10.168.35.22:6383", #mouse
  
  :redis_17 => "redis://10.162.49.39:6379",
  
  :redis_18 => "redis://10.160.40.193:6379",
  
  :redis_19 => "redis://10.171.251.153:6379",
  
  :redis_20 => "redis://10.171.228.17:6382", #hades
  
  :redis_21 => "redis://10.168.26.54:6385", #dragon
  
  :redis_22 => "redis://10.171.228.17:6380", #hades
  
  :redis_23 => "redis://10.168.35.22:6385", #mouse
  
  :redis_24 => "redis://10.168.35.22:6386", #mouse
  
  :redis_25 => "redis://10.168.35.22:6387", #mouse
  
  :redis_26 => "redis://10.162.100.218:6379",
  
  :redis_27 => "redis://10.160.67.75:6379",
  
  :redis_28 => "redis://10.171.247.15:6381", #tortoise

  :redis_31 => "redis://10.161.166.93:6381",

  :redis_29 => "redis://10.171.228.17:6379",  #hades
  
  :redis_15 => "redis://10.160.6.179:6379",
  
  :redis_30 => "redis://10.160.35.76:6379",
  
  :redis_32 => "redis://10.171.246.158:6379"
}



if Rails.env == "development"
  $redis = Redis.new(:host => "127.0.0.1", :port => "6379", :driver => :hiredis)
else
  $redis = Redis::Sharding.new($redis_nodes, :driver => :hiredis, :timeout => 0.75)
end

$redis_hash = RedisHL.new($redis)








