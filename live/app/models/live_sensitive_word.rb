#encoding:utf-8

class LiveSensitiveWord < AdapterLive

  self.table_name = "live_sensitive_words"


  def self.add_sensitive_words(words)
    if words
      words.each { |word|
        unless word_is_exist(word)
          attrs = {
            :sensitive_word => word
          }
          self.create(attrs)
        end
      }
      refresh_sensitive_words
    end
  end

  def self.del_sensitive_words(words)
    if words
      words.each { |word|
        if word_is_exist(word)
          sql = "delete from live_sensitive_words where sensitive_word = '#{word}'"
          LiveSensitiveWord.connection.execute(sql)
          $redis.srem("live_sensitive_words", word)
        end
      }
    end

  end

  def self.word_is_exist(word)
    ans = self.find_by_sql("select * from live_sensitive_words where sensitive_word = '#{word}' limit 1")
    if ans.blank?
      return false
    end
    return true
  end

  def self.refresh_sensitive_words
    sentisive_words = self.find_by_sql("select sensitive_word from live_sensitive_words ")
    sentisive_words.each { |word|
      word = word[:sensitive_word]
      $redis.sadd("live_sensitive_words", word)
    }
  end

  def self.filter_sensitive_word(message)

    unless $redis.exists("live_sensitive_words")
      refresh_sensitive_words
    end

    #干扰字符
    reg = /[\!\@\#\$\%\^\&\*\(\)\\\[\]\;\:\'\"\,\<\.\>\/\?\，\《\。\》\／\？\；\：\‘\“\‘\”\［\｛\］\｝\＝\＋\－\——\）\（\＊\&\％\¥\＃\@\！\｀\～\-\_\=\+\、\｜\|\ ]/
    sensitive_words = $redis.smembers("live_sensitive_words")

    len = message.size
    i = 0
    ss = ""
    sign = {}
    while  i<len
      if reg.match(message[i])
        sign[i] = message[i]
      else
        ss = ss + message[i]
      end
      i = i + 1
    end
    sensitive_words.each { |s|
      if ss.include?(s)
        tem = "*" * s.size
        ss.gsub!(s, tem)
      end
    }
    sign.each { |k, v|
      ss.insert(k, v)
    }
    message = ss

    return message
  end

end
