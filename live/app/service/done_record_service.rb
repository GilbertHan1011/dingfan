require 'thrift/studys_service/studys_service_client'
module DoneRecordService extend ActiveSupport::Concern

  module InstanceMethods
    #current_user => UserAccount
    #arr_done_record => list<BBDoneRecord>
    def submit_done_records(current_user,arr_done_record,current_word_level_id)
      records_to_submit = arr_done_record.map do |r|
        DoneRecordSubmited.new(
          :wordTopicId => r.word_topic_id,
          :currentScore => r.current_score,
          :spanDays => r.span_days,
          :usedTime => r.used_time,
          :doneTimes => r.done_times,
          :wrongTimes => r.wrong_times,
          :isFirstDoAtToday => r.is_first_do_at_today,
          :spellScore => r.spell_score,
          :listeningScore => r.listening_score
        )
      end
      begin
        StudysServiceClient.submit_done_records(current_user.user_id,current_word_level_id,current_user.get_user_type,records_to_submit)
      rescue StandardError => e
        Rails.logger.error "Error.DoneRecordService#submit_done_records => #{e.inspect}"
        raise e
      end
    end
    # current_user => UserAccount
    # return list<DoneRecord>
    def get_user_done_records(current_user,current_word_level_id)
      begin
        return StudysServiceClient.get_user_done_records(current_user.user_id,current_word_level_id,current_user.get_user_type)
      rescue StandardError => e
        Rails.logger.error "Error.DoneRecordService#get_user_done_records => #{e.inspect}"
        raise e
      end
    end
    # current_user => UserAccount
    # arr_param => list<Param>
    # return list<DetailedDoneRecord>
    def get_done_records(current_user,arr_param)
      begin
        return StudysServiceClient.get_done_records(current_user.user_id,arr_param)
      rescue StandardError => e
        Rails.logger.error "Error.DoneRecordService#get_done_records => #{e.inspect}"
        raise e
      end
    end
    # current_user => UserAccount
    def get_count_of_done_records(current_user,current_word_level_id)
      begin
        return StudysServiceClient.get_count_of_done_records(current_user.user_id,current_word_level_id,current_user.get_user_type)
      rescue StandardError => e
        Rails.logger.error "Error.DoneRecordService#get_count_of_done_records => #{e.inspect}"
        raise e
      end
    end
    # current_user => UserAccount
    def get_count_of_today_done_records(current_user,current_word_level_id)
      begin
        return StudysServiceClient.get_count_of_today_done_records(current_user.user_id,current_word_level_id,current_user.get_user_type)
      rescue StandardError => e
        Rails.logger.error "Error.DoneRecordService#get_count_of_today_done_records => #{e.inspect}"
        raise e
      end
    end
    # current_user => UserAccount
    def remove_done_records(current_user,current_word_level_id)
      begin
        StudysServiceClient.remove_done_records(current_user.user_id,current_word_level_id,current_user.get_user_type)
      rescue StandardError => e
        Rails.logger.error "Error.DoneRecordService#remove_done_records => #{e.inspect}"
        raise e
      end
    end


  end

end