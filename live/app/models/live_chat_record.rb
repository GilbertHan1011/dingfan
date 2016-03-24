# encoding: utf-8

class LiveChatRecord < AdapterLive

  self.table_name = "live_chat_records"

  def self.create_live_chat_record(class_name, timestamp, chat_data_json)
    begin
      # attrs = {
      #   :timestamp => timestamp,
      #   :class_name => class_name,
      #   :chat_data_json => chat_data_json
      # }
      # self.create(attrs)
      LiveChatRecord.connection.execute("insert into live_chat_records  (timestamp,class_name,chat_data_json) values (#{timestamp}, '#{class_name}' ,#{sanitize chat_data_json})");
    rescue
      return false
    end

  end


  def self.find_by_class_name_and_timestamp(class_name, timestamp)
    ans = self.find_by_sql("select timestamp,chat_data_json from live_chat_records where timestamp = #{timestamp} and class_name = '#{class_name}' ORDER BY id asc")
    return ans
  end


  def self.get_chat_record_by_class_name_and_timestamp(class_name, timestamp, index, count, isLive)

    #约定当历史记录取完时finish_timestamp为-1
    finish_timestamp = -1

    message_queue = []

    if timestamp <= 0
      #当timestamp<0时，拉取此时间戳前十条数据
      if timestamp < 0
        timestamp = timestamp * -1
        ans = self.find_by_sql("select id,timestamp,chat_data_json from live_chat_records where class_name = '#{class_name}' and timestamp < #{timestamp} ORDER BY id desc LIMIT #{count}")
      else
        #当timestamp=0时，拉取最新十条数据
        ans = self.find_by_sql("select id,timestamp,chat_data_json from live_chat_records where class_name = '#{class_name}'  ORDER BY id desc LIMIT #{count}")
      end
    else
      if index == 0
        ans = self.find_by_sql("select id,timestamp,chat_data_json from live_chat_records where class_name = '#{class_name}' and timestamp <= #{timestamp} ORDER BY id desc LIMIT #{count}")
      else
        ans = self.find_by_sql("select id,timestamp,chat_data_json from live_chat_records where class_name = '#{class_name}' and timestamp <= #{timestamp} and id < #{index} ORDER BY id desc LIMIT #{count}")
      end
    end

    unless ans.blank?
      ans.each{ |record|
        chat_data = record["chat_data_json"]
        chat_data = Base64.decode64(chat_data)
        chat_data = Oj.load(chat_data)
        chat_data["timestamp"] = record["timestamp"].to_i

        #判断是否为直播状态
        if isLive
          message_queue.unshift(chat_data)
        else
          message_queue.push(chat_data)
        end

      }
      record_timestamp = ans[-1]["timestamp"].to_i
      index = ans[-1]["id"].to_i
    else
      record_timestamp = finish_timestamp
      index = 0
    end

    return message_queue, record_timestamp, index
  end

  def self.get_live_message_by_class_name_and_timestamp(class_name, timestamp, index, token)
    #每次拉的最大消息量
    max_message_number = 100

    class_timestamp_set = "#{class_name}_timestamp_set"
    message_queue = []
    timestamp_index = $redis.zrank(class_timestamp_set, timestamp)
    timestamp_list = $redis.zrange(class_timestamp_set, timestamp_index, -1)
    last_timestamp = timestamp_list.last

    if timestamp_index
      mq_index = index
      len = mq_index
      if timestamp_list
        timestamp_list.each { |ts|
          t = ts
          ts = "#{class_name}_mq_#{ts}"
          if $redis.exists(ts)
            len = $redis.llen(ts)
            mq = $redis.lrange(ts, mq_index, len-1)
            if mq
              mq.each { |m|
                m = Oj.load(m)
                m["timestamp"] = t
                if m["tip"] >= 1 #|| m["token"] != token
                  message_queue.push(m)
                end
              }
            end
          else
            #判断此时间戳是否所对应数据库中的消息记录是否为空
            unless $redis.sismember("#{class_name}_timestamp_blank_message_set", t)
              ans = find_by_class_name_and_timestamp(class_name, t)
              unless ans.blank?
                len = ans.size
                ans = ans.map{ |record|
                  chat_data = record["chat_data_json"]
                  chat_data = Base64.decode64(chat_data)
                  #缓存消息记录，避免后面多次重复访问数据库
                  $redis.rpush("#{class_name}_mq_#{t}", chat_data)
                  Oj.load(chat_data)
                }
                $redis.expire("#{class_name}_mq_#{t}", 300)

                ans = ans[mq_index.. -1]
                if ans
                  ans.each{ |record|
                    record["timestamp"] = record["timestamp"].to_i
                    message_queue.push(record)
                  }
                end
              else
                #若此时间戳在数据库中无对应的消息，则把此时间戳记录在空消息的时间戳集合内，避免后面的多次重复访问数据库
                $redis.sadd("#{class_name}_timestamp_blank_message_set", t)
                $redis.expire("#{class_name}_timestamp_blank_message_set", 300)
                len = 0
              end
            else
              len = 0
            end
          end
          #防止一次性拉取消息记录太多，而导致json字符串解析出错
          if message_queue.size > max_message_number
            last_timestamp = t
            break;
          end
          mq_index = 0
        }
      end
      mq_index = len
    else
      if last_timestamp.blank?
        last_timestamp = 0
      end
      mq_index = 0
    end
    return message_queue, last_timestamp, mq_index
  end

end
