#source 'https://rubygems.org'
source 'https://ruby.taobao.org'

if ENV["OS"] =~ /Win.*/
  gem 'rails', '3.2.6'
else
  gem 'rails', '3.2.11'
end


gem 'rack', '~> 1.4.3'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

gem 'mysql2','0.3.18'
gem 'net-ssh'
gem 'net-scp'


# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  # gem 'therubyracer', :platform => :ruby

  gem 'uglifier', '>= 1.0.3'
end

gem 'jquery-rails'

# yet another json parser
gem 'oj'

# To use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.0.0'

# To use Jbuilder templates for JSON
# gem 'jbuilder'

# Use unicorn as the app server
unless ENV["OS"] =~ /Win.*/
  gem 'rainbows'
  gem "hiredis"
end

#gem "redis", "~> 2.2.2"
#gem "redis-namespace", "~> 0.8.0"

gem "redis", "~> 3.0.1"
gem "redis-namespace", "~> 1.2.0"

gem 'bitset'

gem 'hpricot'

if ENV["GEM_PATH"] =~ /2\.2/
  gem 'test-unit'
end


gem 'aws-s3',"~> 0.6.3",:require => 'aws/s3'

#login oauth
gem 'omniauth-weibo-oauth2'
gem 'omniauth-qq-connect'
# gem 'omniauth-renren'

## weibo need
gem 'rest-client'
gem 'mini_magick', '~> 3.8.0'
gem 'delayed_job_active_record'
gem 'daemons'

gem 'will_paginate', '~> 3.0.0'


# thrift
gem 'thrift'
gem 'thin'


#lograge
gem "lograge"
gem "logstash-event"

#memcached
gem 'dalli'

gem 'bunny'
gem 'execjs'
gem 'therubyracer'
gem 'whenever'
#gem 'safe_attributes'
gem 'pili'
gem 'qiniu','6.4.0'
