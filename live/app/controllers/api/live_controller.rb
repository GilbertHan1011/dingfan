# encoding: utf-8

class Api::LiveController < ApiController

  before_filter :check_latest_device, :only => [:get_categories, :get_category_detail, :get_live_url, :thumbs_up, :enter_room, :exit_room, :pull_message, :get_chat_record]

  TYPE_LIVE = 1
  TYPE_PLAYBACK = 2


  # 检查用户登录的设备, 不允许同一个账号在不同设备上登录
  def check_latest_device
    msg = ""

    user = UserAccount.find_by_temporary_token(params[:token])
    if user.blank? || params[:device_id].blank?
      msg = "用户或请求参数有误, 请尝试重新登录后再试!"
    elsif !UserDevice.validate_device_id(user.user_id, params[:device_id])
      msg = "您的账号已在其它设备上登录, 本设备账号自动退出"
    end

    unless msg.blank?
      response_json = Oj.dump({
        "code" => ErrorType::NEED_LOGIN,
        "message" => msg
      })

      respond_to do |format|
        format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
        format.json { render :text => response_json }
      end and return
    end
  end


  # 获取所有主题系列
  def get_categories
    error_code = ErrorType::NO_ERROR
    error_msg = ""

    user = UserAccount.find_by_temporary_token(params[:token])
    if user
      cates = LiveCategory.get_all_categories(user)
    else
      error_code = ErrorType::NOT_VALID
      error_msg = "参数无效"
    end

    response_json = Oj.dump({
      "code" => error_code,
      "message" => error_msg,
      "categories" => cates
    })

    respond_to do |format|
      format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
      format.json { render :text => response_json }
    end
  end


  # 获取指定系列的详细信息, 比如系列的价格, 用户购买情况, 以及系列下的所有课程
  def get_category_detail
    error_code = ErrorType::NO_ERROR
    error_msg = ""

    cate_id = params[:category_id].to_i
    user = UserAccount.find_by_temporary_token(params[:token])
    cate = LiveCategory.find_by_id(cate_id)

    class_infos = []
    if user && cate
      class_ids = Oj.load(cate.try(:live_class_ids) || "[]")
      class_infos = LiveClass.get_classes(user.user_id, class_ids)
    else
      error_code = ErrorType::NOT_VALID
      error_msg = "参数无效"
    end

    response_json = Oj.dump({
      "code" => error_code,
      "message" => error_msg,
      "classes" => class_infos
    })

    respond_to do |format|
      format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
      format.json { render :text => response_json }
    end
  end


  # 获取指定课程的当前状态
  def get_class_status
    error_code = ErrorType::NO_ERROR
    error_msg = ""

    class_status = LiveClass.get_class_status(params[:class_id].to_i)
    if class_status < LiveClass::INTERRUPTED
      error_code = ErrorType::NOT_VALID
      error_msg = "课程状态无效"
    end

    response_json = Oj.dump({
      "code" => error_code,
      "message" => error_msg,
      "class_status" => class_status
    })

    respond_to do |format|
      format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
      format.json { render :text => response_json }
    end
  end


  # 获取直播发布/观看URL
  def get_live_url
    error_code = ErrorType::NO_ERROR
    error_msg = ""
    url = nil
    play_type = nil
    publish_in_advance = 10 #最多可以提前开始发布的分钟数

    class_id = params[:class_id].to_i
    user = UserAccount.find_by_temporary_token(params[:token])
    live_class = LiveClass.find_by_id(class_id)
    if user && live_class
      cdn_live = get_cdn_live(class_id)

      #直播未完成, 需要根据发布或播放来返回对应url
      if live_class.class_status < LiveClass::FINISHED
        # 验证发布权限
        if params[:live_type] == "publish" && live_class.is_publish_authorized?(user.user_id)
          if (left_minutes = live_class.time_to_publish) <= publish_in_advance
            if live_class.class_status <= LiveClass::BROADCASTING
              play_type = TYPE_LIVE
              url = cdn_live.generate_publish_path(live_class.stream, user)
              live_class.broadcast_class
            else
              error_code = ErrorType::NOT_ALLOWED
              error_msg = "课程状态不正常"
            end
          else
            error_code = ErrorType::NOT_ALLOWED
            error_msg = "对不起,距离可发布时间还有#{left_minutes - publish_in_advance}分钟"
          end

          # 验证观看权限
        elsif params[:live_type] == "live"
          if live_class.is_play_authorized?(user.user_id)
            url = cdn_live.generate_live_path(live_class.stream, user)
            play_type = TYPE_LIVE
          else
            error_code = ErrorType::NOT_ALLOWED
            error_msg = "对不起, 您还没有购买该课程"
          end

        else
          error_code = ErrorType::NOT_ALLOWED
          error_msg = "对不起, 您没有相应的操作权限"
        end

      #直播已完成, 返回回播url
      else
        if params[:live_type] == "publish"
          error_code = ErrorType::NOT_ALLOWED
          error_msg = "课程状态不正常"
        elsif params[:live_type] == "live"
          if live_class.is_play_authorized?(user.user_id)
            url = cdn_live.generate_playback_path(live_class)
            play_type = TYPE_PLAYBACK
          else
            error_code = ErrorType::NOT_ALLOWED
            error_msg = "对不起, 您还没有购买该课程"
          end
        end
      end

    else
      error_code = ErrorType::NOT_VALID
      error_msg = "参数无效"
    end

    response_json = Oj.dump({
      "code" => error_code,
      "message" => error_msg,
      "url" => url,
      "play_type" => play_type,
      "remote_time" => Time.now.to_i,
      "start_time" => live_class.try(:ts_start) || 0
    })

    respond_to do |format|
      format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
      format.json { render :text => response_json }
    end
  end


  # 客户端表示准备进入发布阶段, 设置课程状态为即将开始
  def publish_ready
    error_code = ErrorType::NO_ERROR
    error_msg = ""

    user = UserAccount.find_by_temporary_token(params[:token])
    # 检查用户是否有效
    if user
      class_id = params[:class_id].to_i
      live_class = LiveClass.find_by_id(class_id)
      if live_class.is_publish_authorized?(user.user_id)
        unless live_class.ready_class
          error_code = ErrorType::NOT_ALLOWED
          error_msg = "课程状态不正常"
        end
      else
        error_code = ErrorType::NOT_ALLOWED
        error_msg = "对不起, 您没有相应的操作权限"
      end
    end

    response_json = Oj.dump({
      "code" => error_code,
      "message" => error_msg
    })

    respond_to do |format|
      format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
      format.json { render :text => response_json }
    end
  end


  # 发布完成
  def publish_done
    error_code = ErrorType::NO_ERROR
    error_msg = ""

    user = UserAccount.find_by_temporary_token(params[:token])
    # 检查用户是否有效
    if user
      class_id = params[:class_id].to_i
      live_class = LiveClass.find_by_id(class_id)
      # 检查stream是否有效
      if live_class && live_class.is_publish_authorized?(user.user_id)
        # 将对应的课程状态置为finished
        if live_class.finish_class
          # 生成七牛的回播地址, 以及触发视频转码服务
          cdn_live = get_cdn_live(class_id)
          if cdn_live.class == QiniuLive
            stream_obj = cdn_live.get_stream(live_class.stream)
            live_class.update_playback_and_record_by_stream(stream_obj)
          end
        else
          error_code = ErrorType::NOT_ALLOWED
          error_msg = "课程状态不正常"
        end
      else
        error_code = ErrorType::NOT_ALLOWED
        error_msg = "对不起, 您没有相应的操作权限"
      end

    else
      error_code = ErrorType::NOT_VALID
      error_msg = "用户无效"
    end

    response_json = Oj.dump({
      "code" => error_code,
      "message" => error_msg
    })

    respond_to do |format|
      format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
      format.json { render :text => response_json }
    end
  end


  # 为指定课程点赞
  def thumbs_up
    error_code = ErrorType::NO_ERROR
    error_msg = ""

    class_id = params[:class_id].to_i
    user = UserAccount.find_by_temporary_token(params[:token])
    live_class = LiveClass.find_by_id(class_id)
    if user && live_class
      if live_class.is_play_authorized?(user.user_id)
        if UserLive.try_thumb_up(user.user_id, live_class)
          live_class.update_attributes({:thumbs => live_class.thumbs + 1})
        else
          error_code = ErrorType::NOT_ALLOWED
          error_msg = "少侠, 您的赞溢出喽^_^"
        end
      else
        error_code = ErrorType::NOT_ALLOWED
        error_msg = "对不起, 您没有相应的操作权限"
      end
    else
      error_code = ErrorType::NOT_VALID
      error_msg = "参数无效"
    end

    response_json = Oj.dump({
      "code" => error_code,
      "message" => error_msg,
      "thumbs" => live_class.try(:thumbs) || 0
    })

    respond_to do |format|
      format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
      format.json { render :text => response_json }
    end
  end


  # 购买指定的系列
  def buy_category
    error_code = ErrorType::NO_ERROR
    error_msg = ""

    cate_id = params[:category_id].to_i
    user = UserAccount.find_by_temporary_token(params[:token])
    cate = LiveCategory.find_by_id(cate_id)

    if user && cate
      # 获取系列的实时价格
      price = cate.price

      # Step 1: 生成一个新的订单号
      order_id = CommonUtils.gen_order_id(
        Constants::PAY_LIVE_CATEGORY,
        UserLive.get_item_id(user.user_id)
      )

      # Step 2: 更新订单号到用户对应的课程中
      class_ids = Oj.load(cate.live_class_ids)
      success = UserLive.create_or_update_user_lives(user.user_id, class_ids, order_id)
      unless success
        order_id = nil
        price = nil
        error_code = ErrorType::UNKNOWN
        error_msg = "系统订单处理失败, 请稍后重试一下或联系我们."
      end
    else
      error_code = ErrorType::NOT_VALID
      error_msg = "参数无效"
    end

    response_json = {
      "code" => error_code,
      "message" => error_msg,
      "order_id" => order_id,
      "order_price" => price
    }

    respond_to do |format|
      format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
      format.json { render :text => response_json }
    end
  end

  #-------------------------  回调  ----------------------------

  # 支付系统回调支付结果
  def payment_done
    error_code = ErrorType::NO_ERROR
    error_msg = ""

    # Step 1: 验证是否是支付系统发来的回调

    # Step 2: 根据订单号, 为相应的用户添加已购课程
    order_id = params[:out_order_id].to_s
    UserLive.set_paid(order_id)

    render :text => "success"
  end


  # CDN回调流状态通知
  def stream_status_notify
    if params[:live]
      #七牛
      stream_id = params[:live]["data"]["id"]
      status = params[:live]["data"]["status"]

      if stream_id && status
        stream_name = stream_id.split(".").last
        live_class = LiveClass.find_by_stream(stream_name)
        if live_class
          if status == 'connected'
            live_class.resume_class
          elsif status == 'disconnected'
            live_class.interrupt_class
          end
        end
      end

      render :text => "ok", :status => 200

    elsif !params[:app].blank? && params[:app] == "publish.baicizhan.com"
      #网宿
      stream_name = params[:id]
      live_class = LiveClass.find_by_stream(stream_name)
      if live_class
        if request.fullpath.include?("live_cnc_stream_start")
          # 如果流是被动中断状态, 则将流的状态设置为发布中
          live_class.resume_class
        elsif request.fullpath.include?("live_cnc_stream_stop")
          # 如果流仍然是直播状态, 则将流的状态设置成中断
          live_class.interrupt_class
        end
      end

      render :text => "1", :status => 200
    else
      Rails.logger.info "Unknown_stream_status: #{params}"

      render :text => "0", :status => 200
    end
  end

  #--------------------------  网宿回调  ------------------------------

  # 网宿发布鉴权回调
  def auth_publish
    success = 1

    # token原指用户token, 现用于签名的密文
    decoded_sign = DeviceNetwork.decode(params[:token])
    if decoded_sign && params[:stream]
      begin
        properties = Oj.load(decoded_sign)

        user = UserAccount.find_by_temporary_token(properties["access_token"])
        live_class = LiveClass.find_by_stream(params[:stream])

        if live_class && user && live_class.is_publish_authorized?(user.user_id)
          if properties["stream"] == params[:stream] && properties["nonce"].to_i > live_class.last_nonce
            # 鉴权通过, 更新last_nonce, 课程状态, 以及时间片开始时间
            live_class.broadcast_class(properties["nonce"].to_i)
          else
            success = 0
          end
        else
          success = 0
        end
      rescue Exception => e
        Rails.logger.info "Warn: Error happened when doing auth_publish. #{e.inspect}"
        success = 0
      end
    else
      success = 0
    end

    Rails.logger.info "++++++++++auth_publish_params: #{success}"
    render :text => success.to_s
  end


  # 网宿播放鉴权回调
  def auth_play
    success = 1

    # 网宿拉流的专用token(不属于任何用户), 直接放行
    render :text => success.to_s and return if params[:token] == "8bcpHcmWTd9mFeTkjD3xmg=="

    user = UserAccount.find_by_temporary_token(params[:token])
    # 检查用户是否有效
    if user
      stream_name = params[:stream]
      play_type = params[:video_type] # live, vod
      live_class = LiveClass.find_by_stream(stream_name)
      # 检查stream是否有效以及用户是否具有观看指定直播的权限
      if live_class && live_class.is_play_authorized?(user.user_id)
        #TODO more actions here
      else
        success = 0
      end
    else
      success = 0
    end

    Rails.logger.info "----------auth_play_params: #{success}"
    render :text => success.to_s
  end


  #网宿回调, 更新回播地址以及供后期处理的地址
  def playback_done
    begin
      data = Oj.load(Base64.decode64(request.raw_post))
      if data && !data["items"].blank?
        raw_stream = data["inputkey"]
        #raw_stream格式: "baicizhan.neilyuli_cnc_20160315121451.flv"
        stream_array = raw_stream.split(".")[1].split("_")
        stream = stream_array[0..stream_array.size - 2].join("_")
        live_class = LiveClass.find_by_stream(stream)
        if live_class
          data["items"].each do |item|
            live_class.update_playback_and_record_by_url(item["url"])
          end
        end
      end
    rescue Exception => e
      Rails.logger.info "Error:playback_done: Reason:#{e.inspect}. Content:#{request.raw_post}"
    end

    render :text => "ok", :status => 200
  end

  #--------------------------  七牛回调  ------------------------------

  # 七牛MP4转码为HLS的回调通知
  def mp4_2_hls_done
    begin
      if params['live']['desc'].include?('successfully')
        Rails.logger.info "mp4_2_hls_done:source_file_path: #{params['live']['inputKey']}"
        params['live']['items'].each do |item|
          ActiveRecord::Base.connection.update("update av_process set src=#{ActiveRecord::Base.sanitize(params['live']['inputKey'])}, dest=#{ActiveRecord::Base.sanitize(item['key'])}, updated_at=CURRENT_TIMESTAMP where persistent_id=#{ActiveRecord::Base.sanitize(params['live']['id'])}")
          Rails.logger.info "mp4_2_hls_done:target_file_path: #{item['key']}"
        end
      else
        Rails.logger.info "Error: mp4_2_hls_done: #{params['live']['desc']}"
      end
    rescue Exception => e
      Rails.logger.info "Error: mp4_2_hls_done: #{e.message}"
    end

    render :text => "ok", :status => 200
  end


  # 七牛视频拼接的回调通知
  def concat_done
    begin
      if params['live']['desc'].include?('successfully')
        Rails.logger.info "concat_done:source_file_path: #{params['live']['inputKey']}"
        params['live']['items'].each do |item|
          ActiveRecord::Base.connection.update("update av_process set src=#{ActiveRecord::Base.sanitize(params['live']['inputKey'])}, dest=#{ActiveRecord::Base.sanitize(item['key'])}, updated_at=CURRENT_TIMESTAMP where persistent_id=#{ActiveRecord::Base.sanitize(params['live']['id'])}")
          Rails.logger.info "concat_done:target_file_path: #{item['key']}"
        end
      else
        Rails.logger.info "Error: concat_done: #{params['live']['desc']}"
      end
    rescue Exception => e
      Rails.logger.info "Error: concat_done: #{e.message}"
    end

    render :text => "ok", :status => 200
  end


  # 获取七牛流对象
  def get_stream
    qn_live = QiniuLive.new
    stream_obj = qn_live.get_stream(params[:stream_name])
    stream_json = stream_obj.to_json.camelize(:lower)

    render :text => stream_json
  end


  #调试接口: 重置课程状态
  def reset_class
    error_code = ErrorType::NO_ERROR
    error_msg = ""
    admins = [6159646, 19463601]

    class_id = params[:class_id].to_i
    user = UserAccount.find_by_temporary_token(params[:token])
    begin
      start_from = Time.parse(params[:start_from])
    rescue
    end

    if start_from
      if user && admins.include?(user.user_id)
        LiveClass.reset_class(class_id, start_from)
      else
        error_code = ErrorType::NOT_ALLOWED
        error_msg = "对不起, 你没有相应的操作权限"
      end
    else
      error_code = ErrorType::NOT_VALID
      error_msg = "时间格式有误"
    end

    response_json = Oj.dump({
      "code" => error_code,
      "message" => error_msg
    })

    respond_to do |format|
      format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
      format.json { render :text => response_json }
    end
  end

  #-------------------------   直播评论   ------------------------

  # 进入聊天房间
  def enter_room
    class_id = params[:class_id]
    token = params[:token]
    class_name = "test_chat_room_#{class_id}"
    class_timestamp_set = "#{class_name}_timestamp_set"
    member_info = get_info_in_class(class_id, token)

    if  member_info
      member_in_class = Oj.load(member_info)
      nick_name = member_in_class["nick_name"]
      image = member_in_class["image"]
      timestamp = Time.now.to_i
      $redis.rpush("#{class_name}_mq_#{timestamp}", Oj.dump({
        "name" => nick_name,
        "message" => "进入房间" ,
        "is_question" => false,
        "tip" => 0,
        "image" => image,
        "token" => token
      }))
      $redis.expire("#{class_name}_mq_#{timestamp}", 300)
      $redis.zadd(class_timestamp_set, timestamp, timestamp)

      #设置心跳，用来检测用户是否在线，有效时长10秒
      $redis.set("HEARTBEAT_#{class_name}_#{token}", "")
      $redis.expire("HEARTBEAT_#{class_name}_#{token}", 10)

      response = {
        "code" => ErrorType::NO_ERROR,
        "message" => "进入课程成功"
      }
    else
      response = {
        "code" => ErrorType::NOT_ALLOWED,
        "message" => "用户无此课程权限"
      }
    end

    response_json = Oj.dump(response)

    respond_to do |format|
      format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
      format.json { render :text => response_json }
    end
  end


  # 离开聊天房间
  def exit_room
    class_id = params[:class_id]
    class_name = "test_chat_room_#{class_id}"
    token = params[:token]
    member_info = get_info_in_class(class_id, token)

    # 验证用户是否已经进入课程房间
    if member_info
      $redis.del("#{class_name}_#{token}")
      response = {
        "code" => ErrorType::NO_ERROR,
        "message" => "退出课程成功"
      }
    else
      response = {
        "code" => ErrorType::NOT_VALID,
        "message" => "退出课程失败，用户不在课程中"
      }
    end

    response_json = Oj.dump(response)

    respond_to do |format|
      format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
      format.json { render :text => response_json }
    end
  end


  # 发送消息
  def send_message
    #允许消息的最大字符数
    max_allowed_chars = 300

    class_id = params[:class_id]
    class_name = "test_chat_room_#{class_id}"
    token = params[:token]
    member_info = get_info_in_class(class_id, token)

    # 验证用户是否在房间内
    if member_info
      member_in_class = Oj.load(member_info)
      nick_name = member_in_class["nick_name"]
      image = member_in_class["image"]
      timestamp = Time.now.to_i
      class_timestamp_set = "#{class_name}_timestamp_set"

      message = params[:message]
      #判断消息是否无效
      if message.blank? || message.size > max_allowed_chars
        response = {
          "code" => ErrorType::NOT_VALID,
          "message" => "发送消息为空或超过#{max_allowed_chars}个字符"
        }
      else
        #判断消息是否为疑问句
        is_question = CommonUtils.is_a_question?(message)
        #过滤消息中的敏感词
        message = LiveSensitiveWord.filter_sensitive_word(message)
        message_info = Oj.dump({
           "name" => nick_name,
           "image" => image,
           "message" => message,
           "is_question" => is_question,
           "tip" => 1
         })

        # 将消息推入消息列表
        $redis.rpush("#{class_name}_mq_#{timestamp}", message_info)
        $redis.expire("#{class_name}_mq_#{timestamp}", 300)

        # 将时间戳加入集合
        $redis.zadd(class_timestamp_set, timestamp, timestamp)
        $redis.expire(class_timestamp_set, 3600)

        #持久化聊天记录
        persistent_chat_record(class_name, timestamp, message_info)
        response = {
          "code" => ErrorType::NO_ERROR,
          "message" => ""
        }
      end

    else
      response = {
        "code" => ErrorType::NOT_VALID,
        "message" => "发送消息失败，此用户不在课程内"
      }
    end

    response_json = Oj.dump(response)

    respond_to do |format|
      format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
      format.json { render :text => response_json }
    end

  end


  # 拉取消息
  def pull_message
    #约定当历史记录取完时finish_timestamp为-1
    finish_timestamp = -1
    #约定第一次拉取历史记录时begin_timestamp为0
    begin_timestamp = 0

    # 客户端传入的时间戳
    timestamp, index = params[:timestamp].split("_")
    timestamp = timestamp.to_i
    index = index.to_i
    token = params[:token]
    class_id = params[:class_id]
    class_name = "test_chat_room_#{class_id}"

    # 判断用户是否有权限
    if get_info_in_class(class_id, token)
      # 返回给客户端的时间戳
      return_timestamp = 0
      class_timestamp_set = "#{class_name}_timestamp_set"
      message_queue = []
      alive_member = []
      dead_member = []

      #若为第一次拉取实时消息，返回十条历史记录
      if timestamp == 0

        #将此时的时间戳加入时间戳集合
        timestamp_now = Time.now.to_i
        $redis.zadd(class_timestamp_set, timestamp_now, timestamp_now)

        history_timestamp_list = $redis.zrevrange(class_timestamp_set, 0, 1)
        return_timestamp = history_timestamp_list[0].to_i
        record_timestamp = history_timestamp_list[1].to_i

        if record_timestamp == 0
          record_timestamp = return_timestamp * -1
        end
        message_queue, record_timestamp, index = LiveChatRecord.get_chat_record_by_class_name_and_timestamp(class_name, record_timestamp, index, 10, true)
        return_timestamp = "#{return_timestamp || 0}_0"
      else
        message_queue, last_timestamp, mq_index = LiveChatRecord.get_live_message_by_class_name_and_timestamp(class_name, timestamp, index, token)
        return_timestamp = "#{last_timestamp}_#{mq_index}"
      end

      #每拉一次实时消息，就重置此用户心跳，时长为10秒
      $redis.set("HEARTBEAT_#{class_name}_#{token}", "")
      $redis.expire("HEARTBEAT_#{class_name}_#{token}", 10)

      # 获取此课程房间的全部成员信息
      class_info = $redis.hkeys(class_name)

      # 区分出房间内的在线用户与离线用户，大于0为在线，等于0为离线
      class_info.each { |token|
        value = Oj.load($redis.hget(class_name, token))
        info = {
          "nick_name" => value["nick_name"],
          "image" => value["image"]
        }
        #在redis中检测用户的心跳是否存在
        if $redis.exists("HEARTBEAT_#{class_name}_#{token}")
          alive_member.push(info)
        else
          dead_member.push(info)
        end
      }
      #将在线用户按昵称排序
      alive_member = alive_member.sort{ |x, y|
        x["nick_name"] <=> y["nick_name"]
      }

      timestamp = return_timestamp
      response = {
        "code" => ErrorType::NO_ERROR,
        "timestamp" => timestamp,
        "message_data" => message_queue,
        "alive_member" => alive_member,
        "dead_member" => dead_member
      }
    else
      response = {
        "code" => ErrorType::NOT_ALLOWED,
        "message" => "用户无权限"
      }
    end
    response_json = Oj.dump(response)

    respond_to do |format|
      format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
      format.json { render :text => response_json }
    end
  end


  #拉取历史消息
  def get_chat_record

    #约定当历史记录取完时finish_timestamp为-1
    finish_timestamp = -1
    #约定第一次拉取历史记录时begin_timestamp为0
    begin_timestamp = 0

    # 客户端传入的时间戳
    timestamp, index = params[:timestamp].split("_")
    timestamp = timestamp.to_i
    index = index.to_i
    token = params[:token]
    class_id = params[:class_id]
    count = params[:count].to_i
    class_name = "test_chat_room_#{class_id}"
    class_timestamp_set = "#{class_name}_timestamp_set"
    message_queue = []

    #判断用户是否有此课程权限
    if get_info_in_class(class_id, token)
      record_timestamp = timestamp
      if record_timestamp == begin_timestamp
        history_timestamp_list = $redis.zrevrange(class_timestamp_set, 0, 1)
        record_timestamp = history_timestamp_list[0].to_i
      end
      #判断聊天记录是否已取完，若没有取完则从数据库中取，否则返回空数据
      if record_timestamp != finish_timestamp
        #从数据库中获取聊天记录
        message_queue, record_timestamp, index= LiveChatRecord.get_chat_record_by_class_name_and_timestamp(class_name, record_timestamp, index, count, false)
      end
      record_timestamp = "#{record_timestamp}_#{index}"
      response = {
        "code" => ErrorType::NO_ERROR,
        "timestamp" => record_timestamp,
        "message_data" => message_queue,
      }
    else
      response = {
        "code" => ErrorType::NOT_ALLOWED,
        "message" => "用户无权限"
      }
    end

    response_json = Oj.dump(response)

    respond_to do |format|
      format.all { render :text => ActiveSupport::Gzip.compress(response_json) }
      format.json { render :text => response_json }
    end
  end

  private


  def get_cdn_live(class_id)
    return CncLive.new if class_id == 4

    if class_id % 2 == 1
      return QiniuLive.new
    else
      return CncLive.new
    end
  end


  # 持久化聊天记录
  def persistent_chat_record(class_name, timestamp, chat_data_json)
    chat_data_json = Base64.encode64(chat_data_json)
    LiveChatRecord.create_live_chat_record(class_name, timestamp, chat_data_json)
  end


  def get_info_in_class(class_id, token)
    class_name = "test_chat_room_#{class_id}"
    member_in_class = $redis.hget(class_name, token)

    unless member_in_class
      user = UserAccount.find_by_temporary_token(token)
      live_class = LiveClass.find_by_id(class_id)
      if live_class.is_play_authorized?(user.user_id)
        user_account_info = UserAccountInfo.find_by_user_id(user.user_id)
        nick_name = user_account_info.nickname
        image = user_account_info[:image]
        timestamp = Time.now.to_i
        $redis.hsetnx(class_name, token, Oj.dump({
           "status" => 1,
           "nick_name" => nick_name,
           "image" => image
         }))
        $redis.expire(class_name, 3600 * 3)

        class_timestamp_set = "#{class_name}_timestamp_set"
        $redis.zadd(class_timestamp_set, timestamp, timestamp)
        $redis.expire(class_timestamp_set, 3600 * 3)

        class_info = [class_timestamp_set]
        $redis.hset("all_chat_rooms", class_name, Oj.dump(class_info))
        member_in_class = $redis.hget(class_name, token)
      end
    end
    return member_in_class
  end

end

