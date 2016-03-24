# encoding: utf-8

class ApplicationController < ActionController::Base
  protect_from_forgery


  # define as helper method for using in views
  helper_method :login?, :is_oauth_login?, :current_user, :current_version, :current_auth_user, :save_last_login_from, :daka_valid?, :cur_called
  

  before_filter :do_upgrade
  before_filter :redirect_4_user_from_search

  after_filter :set_access_control_headers

  # handle invalid request
  rescue_from ActionView::MissingTemplate, :with => :rescue404
  rescue_from ActiveRecord::RecordNotFound, :with => :rescue404
  rescue_from ActionController::RoutingError, :with => :rescue404
  rescue_from NoMethodError do |exception|
    if exception.to_s.include?("undefined method `ref'")
      rescue404
    else
      raise exception
    end
  end


  def set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Request-Method'] = '*'
  end

  # around_filter :stat_memory
  def stat_memory
    process_status = File.open("/proc/#{Process.pid}/status")
    15.times { process_status.gets }
    rss_before_action = process_status.gets.split[1].to_i
    process_status.close
    
    yield
    
    process_status = File.open("/proc/#{Process.pid}/status")
    15.times { process_status.gets }
    rss_after_action = process_status.gets.split[1].to_i
    process_status.close
    logger.info("CONSUME MEMORY: #{rss_after_action - rss_before_action} \ KB\tNow: #{rss_after_action} KB\t#{request.url}")
  end
  

  def rescue404
    render :file => 'public/404.html', :status => 404, :layout => false and return
  end
  

  def append_info_to_payload(payload)
    super
    payload[:host] = request.host
    payload[:ip] = request.remote_ip
    payload.merge!(params)
    payload.merge!(:time => Time.now.to_s(:db))
    
    params["request_method"] = request.method
    params["status_code"] = payload[:status]
    params["stat_time"] = Time.now.to_i * 1000
    params["remote_ip"] = request.remote_ip
    params["view_runtime"] = payload[:view_runtime]
    params["db_runtime"] = payload[:db_runtime]

    # 打印请求到后端统计系统消息队列
    if payload[:status] >= 200 && payload[:status] < 400
      payload["access_token"] ||= cookies["bcz_notify_token"]
      if payload["access_token"].blank?
        payload["access_token"] = request.headers['token']
        if payload["access_token"].blank?
          payload["access_token"] = params[:token]
        end
      end
      if payload["access_token"].blank?
        if payload["current_user_email"].blank?
          user = nil
        else
          user = UserAccount.find_by_email(payload["current_user_email"])
        end
      else
        user = UserAccount.find_by_temporary_token(payload["access_token"])
      end

      user = UserAccount.find_by_temporary_token(params[:utoken]) unless params[:utoken].blank?

      uid = user.try(:user_id) || -1
      book_id = user.try(:word_level_id) || -1
      is_new_register = user.try("is_new_register?") || false
      account_type = user.try("register_type") || ""
      
      params["user_id"] = params["user_id"].to_i
      params["user_id"] = uid if params["user_id"].nil? || params["user_id"] == 0
      params["book_id"] = book_id if params["book_id"].nil?
      params["is_new_register"]= is_new_register if params["is_new_register"].nil?
      params["account_type"]= account_type if params["account_type"].nil?
    end
    
    STATMQServiceClient.put("baicizhan_user_requests", params)
  end
  
  
  def request_stat
    access_token = params[:access_token]
    if !access_token.blank?
      request_blocked_key = "block_of:#{access_token}"
      request_count_key = "req_of:#{access_token}"
      request_count = $redis_berlin.get(request_count_key).to_i
      
      if $redis_berlin.exists(request_blocked_key)
        respond_to do |format|
          res = { "success" => 0, "messagetype" => 25, "message" => "Hi,少侠。你的请求太过于频繁，请5分钟后再试" }.to_json
          format.all{ render :text => res }
          format.gz{ render :text => ActiveSupport::Gzip.compress(res) }
        end
        
      elsif request_count >= 1500
        $redis_berlin.setex(request_blocked_key, 5.minutes, 1)
        $redis_berlin.del(request_count_key)
        $redis_berlin.sadd("request_black_list", access_token)
        render :nothing => true, :status => 404
        
      else
        $redis_berlin.multi do 
          $redis_berlin.incr(request_count_key)
          $redis_berlin.expire(request_count_key, 1.minutes) if request_count <= 1
        end
      end
    end
  end
  
  
  def do_upgrade    
    if is_upgrading
      respond_to do |format|
        if request.path.include?("api")
          res = { "success" => 0, "messagetype" => 25, "message" => "少侠，你好。我们正在升级百词斩的服务器。很抱歉，在接下来的时间，你将暂时不能使用百词斩的服务。请休息一会儿，稍后再试。" }.to_json
          format.all{ render :text => res }
          format.gz{ render :text => ActiveSupport::Gzip.compress(res) }
        else
          format.html{ redirect_to '/upgrade.html' }
          format.json{ render :text => { :redirect_to => '/upgrade.html' }.to_json }
        end
      end
    end
  end


  def redirect_4_user_from_search    
    url_from = request.referer

    if !login? && !url_from.blank? && cookies[:old_user] != "1" && !url_from.scan(/baidu\.com|google\.com/).blank? &&
        ( url_from.include?("s?word=") or url_from.include?("wd=") or url_from.include?("q=") ) && !url_from.include?("m.baidu.com")
        redirect_to "/hello"
    end
  end

  
  #=======================Private Methods============================


  private


  def login?
    if session[:user_id].blank?
      return false if cookies[:auth_token].blank?
      cookie_user_id = cookies[:auth_token].split(":").first
      cookie_code = cookies[:auth_token].split(":").last
      remembered_user = UserAccount.find_by_user_id(cookie_user_id)
      if remembered_user && remembered_user.remember_me_token == cookie_code
        session[:user_id] = remembered_user.user_id
        return true
      else
        return false
      end
    end
    return true
  end


  def is_oauth_login?
    session[:oauth_user_id].blank? ? false : true
  end


  def current_user
    user = UserAccount.find_by_user_id(session[:user_id])
    sid = session[:session_id]
    cookies[:bcz_account_token] = {:value => sid, :domain => "baicizhan.com"}
    cookies[:access_token] = {:value => user.try(:temporary_token).to_s, :domain => "baicizhan.com", :expires => 7.days.from_now} unless user.blank?
    
    # login 4 baijuzhan
    # if user && Rails.env.production? && $redis_berlin
    #   token_key = "online_auth_of:#{sid}"
    #   if !$redis_berlin.exists(token_key)
    #     $redis_berlin.set(token_key, user.user_id)
    #     $redis_berlin.expireat(token_key, (Time.now + 30.days).to_i)
    #   end
    # end

    user
  end


  def current_auth_user
    #@current_auth_login ||= OauthAccount.find_by_id(session[:oauth_user_id], :select => "id, uid, nickname,provider,atoken,expires_at,gender,customer_id")
    OauthAccount.find_by_id(session[:oauth_user_id], :select => "id, uid, nickname,provider,atoken,expires_at,gender,customer_id")
  end
  
  def cur_called
    current_auth_user && current_auth_user.is_female? ? "女侠" : "少侠"
  end    
    

  def save_last_login_from
    current_user.save_random_token_when_login("web")
  end
  
  def daka_valid?
    daka_providers = ["weibo","weibo_zhannei","renren","renren_zhannei","qq_zhannei","qq_connect"]
    current_auth_user.nil? || daka_providers.include?(current_auth_user.provider)
  end
  
  
  def load_learned_word_list
    this_user = current_user
    word_level_id = this_user.word_level_id
    
    if !word_level_id.blank? && !this_user.learned_word_list_loaded?(word_level_id)
      this_user.load_learned_word_list(word_level_id)
    end
  end
  
  
  def is_upgrading
    return false
  end

  def web_login_from_app
    Rails.logger.error "[APP XCookie] [#{cookies['bcz_notify_token'] || cookies['access_token']}]"
    access_token = cookies['bcz_notify_token'] || cookies['access_token']
    if access_token
      @user = UserAccount.find_by_temporary_token(access_token)
      if @user
        session[:user_id] = @user.user_id
      end
    end
    Rails.logger.error "[Web login from app] [UID #{session[:user_id]}]"
    @user ||= current_user
    params[:current_user_email]=@user.email if @user
  end

  #=======================END OF Private Methods============================


  
  
  
  #======================= Protected Methods============================
  
  protected

  def require_login
    unless login?
      session[:last_url] = request.fullpath

      respond_to do |format|
        format.json{ render :text => { :redirect_to => cut_word_url }.to_json  }
        format.all{ redirect_to login_url, :notice => "少侠【抱拳】，请先登录..." }
      end
    end
  end
  

  # !! don't change if don't know what this is
  # return a git commit hashcode
  def current_version
    "ec67393eab3850b6099772de30c474813ed11615"
  end
  
  
  def redis_key_4_dau_stats
    "dau_of:#{Date.today.to_time.to_i}"
  end


  def http_basic_authenticate
    authenticate_or_request_with_http_basic do |username, password|
      username == "hehe" && password == "haha"
    end
  end
  
  #=======================END OF Protected Methods============================

end
