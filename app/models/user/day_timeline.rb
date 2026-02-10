class User::DayTimeline
  include Serializable

  attr_reader :user, :day, :filter, :visible_boards

  delegate :today?, to: :day

  def initialize(user, day, filter, visible_boards: nil)
    @user, @day, @filter = user, day, filter
    @visible_boards = visible_boards
  end

  def has_activity?
    events.any?
  end

  def events
    filtered_events.where(created_at: window).order(created_at: :desc)
  end

  def next_day
    latest_event_before&.created_at
  end

  def earliest_time
    next_day&.tomorrow&.beginning_of_day
  end

  def latest_time
    day.yesterday.beginning_of_day
  end

  def added_column
    @added_column ||= build_column(:added, I18n.t("columns.added"), 1, events_in_latest_per_card.where(action: %w[card_published card_reopened]))
  end

  def updated_column
    @updated_column ||= build_column(:updated, I18n.t("columns.updated"), 2, events_in_latest_per_card.where.not(action: %w[card_published card_closed card_reopened]))
  end

  def closed_column
    @closed_column ||= build_column(:closed, I18n.t("columns.done"), 3, events_in_latest_per_card.where(action: "card_closed"))
  end

  def cache_key
    ActiveSupport::Cache.expand_cache_key [ user, filter, day.to_date, events ], "day-timeline"
  end

  private
    TIMELINEABLE_ACTIONS = %w[
      card_assigned
      card_unassigned
      card_mentioned
      card_unmentioned
      card_published
      card_closed
      card_reopened
      card_collection_changed
      card_board_changed
      card_postponed
      card_auto_postponed
      card_triaged
      card_sent_back_to_triage
      comment_created
      comment_mentioned
      comment_unmentioned
    ]

    def filtered_events
      @filtered_events ||= begin
        events = timelineable_events
        events = events.where(creator_id: filter.creators.ids) if filter.creators.present?
        events
      end
    end

    def timelineable_events
      Event
        .preloaded
        .only_kept_eventables
        .where(board: boards)
        .where(action: TIMELINEABLE_ACTIONS)
    end

    # 当调用方显式传入 visible_boards（如查看他人首页时的权限范围）时，必须仅用该范围，不可回退到 user.boards，否则会泄露无权限看板的动态。
    # 单用户账户内用 account.boards，与看板列表短路一致
    def boards
      if visible_boards.nil?
        filter.boards.presence || (user.account_single_user? ? user.account.boards : user.boards)
      else
        visible_boards
      end
    end

    def latest_event_before
      filtered_events.where(created_at: ...day.beginning_of_day).chronologically.last
    end

    def build_column(id, base_title, index, events)
      Column.new(self, id, base_title, index, events)
    end

    def window
      day.all_day
    end

    # 每张卡片在首页只展示一次：仅保留该卡片当天「最后一次」事件所在列，避免同一卡片在「添加 / 更新 / 完成」多列重复出现。
    def events_in_latest_per_card
      events.where(id: latest_event_ids_per_card)
    end

    def latest_event_ids_per_card
      @latest_event_ids_per_card ||= begin
        loaded = events.load
        # 每张卡片只保留最新一条事件（created_at 相同时按 id 比较），避免首页同一卡片重复展示
        latest_by_card = loaded.each_with_object({}) do |e, acc|
          cid = e.card&.id
          next if cid.nil?
          prev = acc[cid]
          acc[cid] = e if prev.nil? || ([ e.created_at, e.id ] <=> [ prev.created_at, prev.id ]) >= 0
        end
        latest_by_card.values.map(&:id).to_set
      end
    end
end
