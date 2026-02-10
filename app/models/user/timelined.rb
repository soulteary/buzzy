module User::Timelined
  extend ActiveSupport::Concern

  included do
    has_many :accessible_events, through: :boards, source: :events
  end

  def timeline_for(day, filter:, visible_boards: nil)
    User::DayTimeline.new(self, day, filter, visible_boards: visible_boards)
  end
end
