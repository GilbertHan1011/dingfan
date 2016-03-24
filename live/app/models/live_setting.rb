# encoding: utf-8

class LiveSetting < AdapterLive

  self.table_name = "live_settings"


  def self.create_live_setting(setting_id, width, height, fps, kbps, kbps_min, kbps_max)
    self.create!({
      :setting_id => setting_id,
      :width => width,
      :height => height,
      :fps => fps,
      :kbps => kbps,
      :kbps_min => kbps_min,
      :kbps_max => kbps_max
    })
  end

end
