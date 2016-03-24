class UserAccount < AdapterAccount

  self.table_name = "user_account_template"

  attr_reader :raw_pwd
  attr_accessor :raw_pwd_confirmation
  attr_accessible :id, :user_id, :email, :phone, :password, :temporary_password, :temporary_token, :temporary_token_updated_at, :public_key, :public_key_updated_at, :register_device_type, :created_at, :updated_at, :raw_pwd, :raw_pwd_confirmation

  USER_SIZE_PER_TABLE = 1500_0000

  def self.find_by_temporary_token(token)
    return nil if token.blank?

    real_token = token.gsub(" ", "+")

    # 先查缓存中是否有user
    cache_key = RedisKeyDict.redis_key_4_user(real_token)
    user_cache = $redis.get(cache_key)
    user = DeviceNetwork.load(user_cache)

    if user.blank?
      user_id = DeviceNetwork.decode_token(real_token).to_i
      if user_id > 0
        user = self.find_by_user_id(user_id)
      else
        # 兼容还没有替换成新token的用户
        # c = Customer.find_by_temporary_token(real_token)
        # user = self.embrace_legacy(c)
      end

      unless user.blank?
        $redis.set(cache_key, DeviceNetwork.dump(user))
        $redis.expire(cache_key, 10 * 60)
      end
    end

    return user
  end

  def self.find_by_user_id(user_id)
    return nil if user_id.blank?
    user_id = user_id.to_i

    begin
      rs = self.db_query_by_user_id(user_id)
      return rs
        # if rs.blank?
        #   c = Customer.find_by_id(user_id)
        #   return self.embrace_legacy(c)
        # else
        #   return rs
        # end
    rescue Exception => e
      Rails.logger.error "Error:UserAccount:find_by_user_id: #{e.message}"
      return nil
    end
  end

  def self.db_query_by_user_id(user_id)
    begin
      rs = UserAccount.connection.select("select * from #{self.get_table_name(user_id)} where user_id = #{user_id}").first
      if rs.blank?
        return nil
      else
        return UserAccount.new(rs)
      end
    rescue Exception => e
      Rails.logger.error "Error:UserAccount:db_query_by_user_id: #{e.message}"
      return nil
    end
  end

  def self.get_table_name(user_id)
    return "user_account_t#{user_id / USER_SIZE_PER_TABLE}"
  end

end
