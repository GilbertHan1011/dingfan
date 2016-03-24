#encoding:utf-8

class UserDevice < AdapterAccount

  self.table_name = "user_device_template"

  USER_SIZE_PER_TABLE = 1500_0000

  # 检查用户最近一次登录的设备是否是该设备
  def self.validate_device_id(user_id, device_id)
    user_device_id_cache = "#{user_id}_device_id_cache"

    #检查缓存中的device_id是否与传入的device_id相同
    if $redis.exists(user_device_id_cache) && $redis.get(user_device_id_cache) == device_id
      $redis.expire(user_device_id_cache, 10 * 60)
      return true
    end
    sql = "select * from #{self.get_table_name(user_id)} where user_id = #{user_id} and latest_device_id = #{self.sanitize(device_id)}"

    begin
      record = self.connection.select(sql)
      if record.blank?
        return false
      else
        #更新缓存中的device_id
        device_id = record[0]["latest_device_id"]
        $redis.set(user_device_id_cache, device_id)
        $redis.expire(user_device_id_cache, 10 * 60)

        return true
      end
    rescue Exception => e
      return false
    end
  end


  # 更新用户最近一次登录的设备id
  def self.update_user_latest_device(user_id, device_id)
    ret = false

    return ret if device_id.blank?

    retry_times = 2
    begin
      sql = "update #{self.get_table_name(user_id)} set latest_device_id = #{self.sanitize(device_id)}, updated_at = CURRENT_TIMESTAMP where user_id = #{user_id}"

      affected_rows = self.connection.update(sql)
      if affected_rows == 1
        ret = true
      elsif affected_rows == 0
        sql = "insert into #{self.get_table_name(user_id)} (user_id, latest_device_id, created_at, updated_at) values (#{user_id}, #{self.sanitize(device_id)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
        self.connection.insert(sql)
        ret = true
      end

      #使原有缓存中的device_id失效
      user_device_id_cache = "#{user_id}_device_id_cache"
      $redis.del(user_device_id_cache)

    rescue Exception => e
      retry_times -= 1

      if retry_times > 0
        if e.message.include?("doesn't exist")
          create_table_sql = "create table #{self.get_table_name(user_id)} like user_device_template"
          self.connection.execute(create_table_sql)
        end

        retry
      else
        Rails.logger.info "Error: Cannot update_user_latest_device: #{e.inspect}"
      end
    end

    return ret
  end


  def self.get_table_name(user_id)
    "user_device_t#{user_id / USER_SIZE_PER_TABLE}"
  end
end
