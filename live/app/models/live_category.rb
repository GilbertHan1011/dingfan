#encoding:utf-8

class LiveCategory < AdapterLive

  self.table_name = "live_categories"


  # 获取有效的直播系列的列表
  def self.get_all_categories(user)
    display_cate_name = false
    ret = []
    user_id = user.user_id
    bought_class_ids = UserLive.get_bought_class_ids(user_id)

    if user.get_user_type == Constants::ALPHA_USER
      cates = self.find_by_sql("select * from live_categories order by created_at desc")
    else
      cates = self.find_by_sql("select * from live_categories where enabled = true order by created_at desc")
    end

    cates.each do |cate|
      cate_class_ids = Oj.load(cate.live_class_ids)
      if cate_class_ids & bought_class_ids == cate_class_ids
        is_bought = true
      else
        is_bought = false
      end

      ret << {
        "category_id" => cate.id,
        "category_name" => display_cate_name ? cate.category_title.to_s : "",
        "category_subname" => cate.category_subtitle.to_s,
        "category_cover" => cate.category_cover.blank? ? "" : File.join( Live::ASSETS_DIR_CONFIG[Rails.env]["qiniu_res_dns"], "live/#{cate.category_cover}?time=#{rand(0..99999)}" ),
        "category_desc" => cate.category_desc.to_s,
        "price" => cate.price,
        "is_bought" => is_bought
      }
    end

    return ret
  end


  # 创建一个直播系列
  def self.create_live_category(title, cover, subtitle = "", desc = "", class_ids = [], enabled = true)
    attrs = {
      :category_title => title,
      :category_subtitle => subtitle,
      :category_cover => cover,
      :category_desc => desc,
      :live_class_ids => Oj.dump(class_ids),
      :enabled => enabled
    }
    obj = self.create(attrs)
  end


  # 为指定的系列添加课程, 一般用于将新课程添加到已存在的系列之中
  def self.add_classes(cate_id, class_ids = [])
    unless class_ids.blank?
      cate = self.find_by_id(cate_id)
      if cate
        old_classes = Oj.load(cate.live_class_ids || "[]")
        new_classes = class_ids | old_classes

        cate.update_attributes(:live_class_ids => Oj.dump(new_classes))

        return new_classes.size - old_classes.size
      end
    end

    return 0
  end
end
