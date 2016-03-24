# encoding: utf-8

class UserLive < AdapterLive

  self.table_name = "user_lives_template"

  ITEMS_PER_TABLE = 400_0000


  # 创建用户课程项, 成功返回true, 失败返回false
  def self.create_or_update_user_lives(user_id, class_ids, order_id, thumbed = false)
    return false if class_ids.blank? || user_id.blank?

    is_thumbed = thumbed ? 'true' : 'false'
    retry_times = 2
    begin
      self.transaction do
        class_ids.each do |class_id|
          sql = "insert into #{self.get_table_name(user_id)} (user_id, live_class_id, order_id, thumbed, created_at, updated_at) values (#{user_id}, #{class_id}, #{self.sanitize(order_id)}, '#{is_thumbed}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) on duplicate key update order_id = #{self.sanitize(order_id)}, updated_at = CURRENT_TIMESTAMP"

          self.connection.insert(sql)
        end
      end

      return true
    rescue Exception => e
      if e.message.include?("doesn't exist") && retry_times > 0
        retry_times -= 1
        self.connection.execute("create table #{self.get_table_name(user_id)} like user_lives_template")
        retry
      else
        Rails.logger.info "Error:Cannot create user live class for user:#{user_id} order_id:#{order_id} Reason: #{e.inspect}"
        return false
      end
    end
  end


  # 将指定订单号的课程都设置为已购买
  def self.set_paid(order_id)
    begin
      sql = "update #{self.get_table_name_by_order_id(order_id)} set is_paid = true, updated_at = CURRENT_TIMESTAMP where order_id = #{self.sanitize(order_id)}"

      affected = self.connection.update(sql)
      return affected > 0 ? true : false
    rescue Exception => e
      Rails.logger.info "Error:Cannot set_paid for order:#{order_id} Reason: #{e.inspect}"
      return false
    end
  end


  # 获取指定用户所有已购买的课程id
  def self.get_bought_class_ids(user_id)
    lives = []

    begin
      lives = self.find_by_sql("select live_class_id from #{self.get_table_name(user_id)} where user_id = #{user_id} and is_paid = true")
    rescue Exception => e
    end

    return lives.map{|x| x.live_class_id}
  end


  # 获取用户已经点过赞的课程id
  def self.get_thumbed_class_ids(user_id)
    lives = []

    begin
      lives = self.find_by_sql("select live_class_id from #{self.get_table_name(user_id)} where user_id = #{user_id} and thumbed = true")
    rescue Exception => e
    end

    return lives.map{|x| x.live_class_id}
  end


  # 用户为指定课程点赞, 若成功点赞返回true, 若失败返回false
  def self.try_thumb_up(user_id, live_class)
    return false if live_class.blank?

    sql = "select * from #{self.get_table_name(user_id)} where user_id = #{user_id} and live_class_id = #{live_class.id}"
    begin
      exist = self.find_by_sql(sql).first
    rescue Exception => e
    end

    if exist.blank? && live_class.is_public
      return self.create_or_update_user_lives(user_id, [live_class.id], nil, true)
    elsif exist
      return false if exist.thumbed

      exist.thumbed = true
      exist.save
      return true
    else
      return false
    end
  end


  # 获取用户数据所在表名
  def self.get_table_name(user_id)
    "user_lives_t#{user_id / ITEMS_PER_TABLE}"
  end


# 从订单号中解析出订单所在的表名
  def self.get_table_name_by_order_id(order_id)
    suffix = order_id[21..order_id.size-1]
    "user_lives_t#{suffix}"
  end


  # 生成系列订单的识别码
  def self.get_item_id(user_id)
    "#{user_id / ITEMS_PER_TABLE}"
  end
end
