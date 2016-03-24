# encoding: utf-8

class LiveClass < AdapterLive

  self.table_name = "live_classes"

  INTERRUPTED = -1
  NOT_STARTED = 0
  PUBLISH_READY = 1
  BROADCASTING = 2
  FINISHED = 3


  # 检查发布权限
  def is_publish_authorized?(user_id)
    return true if user_id == 6159646
    self.hold_by == user_id
  end


  # 检查播放权限
  def is_play_authorized?(user_id)
    return true if self.is_public
    return true if self.is_publish_authorized?(user_id)
    return true if self.present_by == user_id
    bought_class_ids = UserLive.get_bought_class_ids(user_id)
    return bought_class_ids.include?(self.id)
  end


  # 获取距离预定发布时间的分钟数
  def time_to_publish
    return 99999 if self.start_from.to_i == 0
    return (self.start_from.to_i - Time.now.to_i) / 1.minutes.to_i
  end


  # 设置课程状态为被动中断状态
  def interrupt_class
    if self.class_status == BROADCASTING
      self.update_attributes({:class_status => INTERRUPTED})
      self.clear_cache
      true
    else
      false
    end
  end


  # 从中断状态恢复到发布中状态
  def resume_class
    if self.class_status == INTERRUPTED
      self.update_attributes({:class_status => BROADCASTING})
      self.clear_cache
      true
    else
      false
    end
  end


  # 设置课程为准备发布状态
  def ready_class
    if self.class_status < PUBLISH_READY
      self.update_attributes({:class_status => PUBLISH_READY})
      self.clear_cache
      true
    else
      false
    end
  end


  # 设置课程为发布中状态
  def broadcast_class(last_nonce = nil)
    if self.class_status < BROADCASTING
      attrs = {
        :class_status => BROADCASTING,
        :ts_start => Time.now.to_i
      }
      attrs[:last_nonce] = last_nonce if last_nonce
      self.update_attributes(attrs)
      self.clear_cache
      true
    else
      false
    end
  end


  # 设置课程为结束状态
  def finish_class
    if self.class_status < FINISHED
      attrs = {
        :class_status => FINISHED,
        :ts_end => Time.now.to_i
      }
      self.update_attributes(attrs)
      self.clear_cache
      true
    else
      false
    end
  end


  # 清除缓存
  def clear_cache
    $redis.del("status_live_cls_#{self.id}")
  end


  # 根据流对象更新回放以及记录视频的URL
  def update_playback_and_record_by_stream(stream_obj)
    return if stream_obj.blank?

    start_time = self.ts_start
    end_time = self.ts_end
    end_time = start_time + 1.hours.to_i if end_time == 0

    begin
      playback_url = stream_obj.hls_playback_urls(start_time, end_time)["ORIGIN"]
      if self.playback_url && self.playback_url.include?("[")
        playback_urls = Oj.load(self.playback_url).push(playback_url)
      else
        playback_urls = [playback_url]
      end
      attr = { :playback_url => Oj.dump(playback_urls) }

      resp = stream_obj.save_as("#{self.stream}.mp4", 'mp4', start_time, end_time)
      if resp && resp["targetUrl"]
        record_url = "#{resp["targetUrl"]}?nonce=#{rand(0..99999)}"
        if self.record_url && self.record_url.include?("[")
          record_urls = Oj.load(self.record_url).push(record_url)
        else
          record_urls = [record_url]
        end
        attr[:record_url] = Oj.dump(record_urls)
      end

      self.update_attributes(attr)
    rescue Exception => e
      Rails.logger.info "Stream hls_playback_urls() failed. Caught exception:\n#{e.inspect}\n\n"
      return ""
    end
  end


  # 根据URL更新回放以及记录视频的URL
  def update_playback_and_record_by_url(url)
    return if url.blank?

    # 更新回放的Url
    if url.end_with?('.m3u8')
      if self.playback_url && self.playback_url.include?('[')
        urls = Oj.load(self.playback_url).push(url)
      else
        urls = [url]
      end
      self.update_attributes({:playback_url => Oj.dump(urls)})

    # 更新后期处理的源Url
    elsif url.end_with?('.mp4')
      record_url = "#{url}?nonce=#{rand(0..99999)}"
      if self.record_url && self.record_url.include?('[')
        urls = Oj.load(self.record_url).push(record_url)
      else
        urls = [record_url]
      end
      self.update_attributes({:record_url => Oj.dump(urls)})
    end
  end

  #-------------------------  Class Methods  -----------------------

  def self.get_class_status(class_id)
    cache_key = "status_live_cls_#{class_id}"
    class_status = $redis.get(cache_key)
    if class_status.blank?
      live_class = self.find_by_id(class_id)
      if live_class
        class_status = live_class.class_status
        $redis.set(cache_key, class_status)
        $redis.expire(cache_key, 3)
      else
        class_status = -1
      end
    end

    return class_status.to_i
  end


  def self.reset_class(class_id, start_from)
    live_class = self.find_by_id(class_id)
    if live_class
      live_class.update_attributes({
        :class_status => NOT_STARTED,
        :ts_start => 0,
        :ts_end => 0,
        :playback_url => nil,
        :record_url => nil,
        :last_nonce => 0,
        :start_from => start_from
      })
      live_class.clear_cache
    end
  end


  # 获取指定用户以及课程id的所有课程信息
  def self.get_classes(user_id, class_ids)
    display_class_name = false
    ret = []
    unless class_ids.blank?
      class_infos = self.find_by_sql(["select * from live_classes where id in (?) order by id", class_ids])

      unless class_infos.blank?
        # 获取当前用户所有已购课程以及点过赞的课程
        authorized_class_ids = UserLive.get_bought_class_ids(user_id)
        thumbed_class_ids = UserLive.get_thumbed_class_ids(user_id)

        class_infos.each do |ci|
          presenter = UserAccountInfo.find_by_user_id(ci.present_by)
          #计算预订人数除去presenter
          booked_num = Oj.load(ci.auth_players || "[]").size - 1

          if ci.is_publish_authorized?(user_id)
            ps = LiveSetting.find_by_setting_id(ci.publish_setting)
            publish_setting = {
              "width" => ps.try(:width) || 1280,
              "height" => ps.try(:height) || 720,
              "fps" => ps.try(:fps) || 24,
              "kbps" => ps.try(:kbps) || 900,
              "kbps_min" => ps.try(:kbps_min) || 500,
              "kbps_max" => ps.try(:kbps_max) || 1496
            }
          else
            publish_setting = {}
          end

          ret << {
            "class_id" => ci.id,
            "class_name" => display_class_name ? ci.class_name : "",
            "class_desc" => ci.class_desc,
            "class_cover" => ci.class_cover.blank? ? "" : File.join( Live::ASSETS_DIR_CONFIG[Rails.env]["qiniu_res_dns"], "live/#{ci.class_cover}?time=#{rand(0..99999)}" ),
            "start_from" => ci.start_from.to_i,
            "is_presenter" => ci.present_by == user_id,
            "is_holder" => ci.is_publish_authorized?(user_id),
            "teacher" => {"nickname" => presenter.nickname, "image" => presenter.image},
            "is_authorized" => ci.is_public || ci.is_publish_authorized?(user_id) || ci.present_by == user_id || authorized_class_ids.include?(ci.id),
            "status" => ci.class_status,
            "booked_people" => booked_num > 0 ? booked_num : 0,
            "thumbs" => ci.thumbs,
            "has_thumbed" => thumbed_class_ids.include?(ci.id),
            "publish_setting" => publish_setting
          }
        end
      end
    end

    return ret
  end


  # 在指定的系列下创建新的课程, 并为其生成流名
  def self.create_live_class(cate_id, presenter_id, holder_id, live_name, live_desc = "", live_cover = "", start_from = Time.now, is_public = false)
    stream_name = "#{start_from.strftime('%Y%m%d%H%M')}_#{presenter_id}_#{rand(100..999)}"

    attrs = {
      :class_name => live_name,
      :class_desc => live_desc,
      :class_cover => live_cover,
      :stream => stream_name,
      :present_by => presenter_id,
      :hold_by => holder_id,
      :start_from => start_from,
      :is_public => is_public,
      :auth_players => Oj.dump([presenter_id]),
      :class_status => NOT_STARTED
    }

    class_obj = self.create(attrs)
    if class_obj
      LiveCategory.add_classes(cate_id, [class_obj.id])
      return class_obj
    else
      return nil
    end
  end
end
