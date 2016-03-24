# encoding: utf-8
require 'json'

class ApiController < ApplicationController
  skip_before_filter :verify_authenticity_token


  def check_infos
    dns_config_json = {  
      "update_at_of_info" => 1370534400,
      "update_at_of_notify_info" => 1387519985,
      "update_at_of_word_fm_halftime_audio" => 1400058914,
      "log_request" => 1,
      "domain" => "http://www.baicizhan.com",
      "log_blacklist" => ["qiniudn.com", "qiniucdn.com"]
    }.to_json
    
    respond_to do |format|
      format.all{ render :text => dns_config_json }
      format.gz{ render :text => ActiveSupport::Gzip.compress(dns_config_json) }
    end
  end
  
end
