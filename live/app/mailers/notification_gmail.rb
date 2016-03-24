# encoding: utf-8

class NotificationGmail < ActionMailer::Base
  #default :from => "百词斩 <#{EmailConfig["default_email"]["email"]}>"
  default :from => "百词斩 <#{EmailConfig["ex_qq"]["email"]}>"

  # def set_smtp
  #   NotificationGmail.smtp_settings = NotificationGmail.smtp_settings.merge({
  #     :user_name => EmailConfig["default_email"]["email"],
  #     :password => EmailConfig["default_email"]["password"],
  #     :from => EmailConfig["default_email"]["email"]
  #   })
  # end


  def set_smtp
    NotificationGmail.smtp_settings = NotificationGmail.smtp_settings.merge({
      :user_name => EmailConfig["ex_qq"]["email"],
      :password => EmailConfig["ex_qq"]["password"],
      :from => EmailConfig["ex_qq"]["email"]
    })
  end


  def confirm_of_reset_pwd(user)
    set_smtp
    @random_pwd = 6.times.map{ rand(9).to_s }.join
    user.update_attributes({"temporary_password" => Digest::MD5.hexdigest(@random_pwd).upcase})
    @url = "http://www.baicizhan.com/setting"
    mail(:to => user.email, :subject =>"重置您的百词斩登录密码[baicizhan.com]")
  end

end
