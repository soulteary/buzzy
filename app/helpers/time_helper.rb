module TimeHelper
  # 返回相对时间的可读文案，如 "5 分钟前"、"2 小时前"、"3 天前"，用于「所有人的内容」等页面的「最近更新」
  def relative_time_ago(datetime)
    return "" if datetime.blank?
    secs = (Time.current - datetime).to_i
    if secs < 60
      I18n.t("square.all_content.just_now")
    elsif secs < 3600
      I18n.t("square.all_content.minutes_ago", count: (secs / 60))
    elsif secs < 86400
      I18n.t("square.all_content.hours_ago", count: (secs / 3600))
    else
      I18n.t("square.all_content.days_ago", count: (secs / 86400))
    end
  end

  def local_datetime_tag(datetime, style: :time, **attributes)
    content = local_time_placeholder(datetime, style)
    tag.time content, **attributes, datetime: datetime.to_i, data: { local_time_target: style, action: "turbo:morph-element->local-time#refreshTarget" }
  end

  private

  def local_time_placeholder(datetime, style)
    case style.to_s
    when "daysago"
      tag.span(local_time_days_ago_text(datetime), class: "local-time-value")
    when "indays"
      tag.span(local_time_in_days_text(datetime), class: "local-time-value")
    else
      "&nbsp;".html_safe
    end
  end

  def local_time_days_ago_text(datetime)
    days = (Time.current.to_date - datetime.to_date).to_i
    if days <= 0
      I18n.t("shared.time.today")
    elsif days == 1
      I18n.t("shared.time.yesterday")
    else
      I18n.t("shared.time.days_ago", count: days)
    end
  end

  def local_time_in_days_text(datetime)
    days = (datetime.to_date - Time.current.to_date).to_i
    if days <= 0
      I18n.t("shared.time.today")
    elsif days == 1
      I18n.t("shared.time.tomorrow")
    else
      I18n.t("shared.time.in_days", count: days)
    end
  end
end
