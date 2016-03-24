class AdapterAccount < ActiveRecord::Base

  establish_connection "#{Rails.env}_account"

end
