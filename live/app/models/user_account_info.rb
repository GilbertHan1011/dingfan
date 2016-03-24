class UserAccountInfo < AdapterAccount

  self.table_name = "user_account_info_template"

  attr_accessible :id, :user_id, :nick_name, :gender, :word_level_id, :image, :position, :ip, :ip_b, :ip_c, :province, :city, :district, :last_login_at, :created_at, :updated_at

  USER_SIZE_PER_TABLE = 1500_0000

  def self.find_by_user_id(user_id)
    return nil if user_id.blank?

    begin
      rs = AdapterAccount.connection.select("select * from #{self.get_table_name(user_id)} where user_id = #{user_id}").first
      if rs.blank?
        return nil
      else
        return UserAccountInfo.new(rs)
      end
    rescue
      return nil
    end
  end

  def nickname(need_escape=false)
    o_account = self.nick_name
    if o_account.blank?
      user = UserAccount.find_by_user_id(self.user_id)
      o_account = CommonUtils.generate_protected_email(user.email)
    elsif o_account.include?('@') && o_account.include?('.')
      o_account = CommonUtils.generate_protected_email(o_account)
    end

    if need_escape
      o_account = ERB::Util.html_escape(o_account)
    end

    o_account
  end

end






