class AdapterLive < ActiveRecord::Base
  establish_connection "#{Rails.env}_live"

end
