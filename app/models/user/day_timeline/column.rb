class User::DayTimeline::Column
  include ActionView::Helpers::TagHelper, ActionView::Helpers::OutputSafetyHelper, TimeHelper

  attr_reader :index, :id, :base_title, :day_timeline, :events

  def initialize(day_timeline, id, base_title, index, events)
    @id = id
    @day_timeline = day_timeline
    @base_title = base_title
    @index = index
    @events = events
  end

  def title
    date_tag = local_datetime_tag(day_timeline.day, style: :agoorweekday)
    parts = [ base_title, date_tag ]
    parts << tag.span("(#{full_events_count})", class: "font-weight-normal") if full_events_count > 0
    safe_join(parts, " ")
  end

  # 每张卡片在时间块内只展示一条：按 card 去重，避免同一卡片在同一列重复渲染
  def events_by_hour
    one_per_card.group_by { |e| e.created_at.hour }
  end

  def has_more_events?
    one_per_card.size < full_events_count
  end

  def hidden_events_count
    full_events_count - one_per_card.size
  end

  def to_param
    id
  end

  private
    def limited_events
      @limited_events ||= events.limit(100).load
    end

    def one_per_card
      @one_per_card ||= limited_events.uniq { |e| e.card&.id }
    end

    def full_events_count
      @full_events_count ||= events.count
    end
end
