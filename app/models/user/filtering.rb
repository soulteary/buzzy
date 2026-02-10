class User::Filtering
  attr_reader :user, :filter, :expanded

  delegate :as_params, :single_board, to: :filter
  delegate :only_closed?, to: :filter

  def initialize(user, filter, expanded: false)
    @user, @filter, @expanded = user, filter, expanded
  end

  def boards
    @boards ||= user.boards_visible_in_dropdown
  end

  def selected_board_titles
    filter.board_titles
  end

  def selected_boards_label
    return I18n.t("filters.my.assigned_to_me_cards") if assigned_to_me_only?
    return I18n.t("filters.my.added_by_me_cards") if added_by_me_only?
    filter.boards_label
  end

  def tags
    @tags ||= account.tags.all.alphabetically
  end

  # 指派人选项与「所有人的内容」中的用户范围一致（全部活跃用户），便于按同一批用户筛选
  def users
    @users ||= User.scope_for_all_content(admin: false).alphabetically
  end

  def filters
    @filters ||= user.filters.all
  end

  def expanded?
    @expanded
  end

  def any?
    filter.used?(ignore_boards: true)
  end

  def show_indexed_by?
    !filter.indexed_by.all?
  end

  def show_sorted_by?
    !filter.sorted_by.latest?
  end

  def show_tags?
    return unless Tag.any?
    filter.tags.any?
  end

  def show_assignees?
    filter.assignees.any?
  end

  def show_creators?
    filter.creators.any?
  end

  def show_closers?
    filter.closers.any?
  end

  def show_boards?
    filter.boards.any?
  end

  def single_board_or_first
    # Default to the first selected or, when no selection, to the first one
    filter.boards.first || boards.first
  end

  def cache_key
    ActiveSupport::Cache.expand_cache_key([ user, filter, expanded?, boards, tags, users, filters ], "user-filtering")
  end

  private
    def account
      user.account
    end

    def assigned_to_me_only?
      filter.assignees.one? && filter.assignees.include?(user)
    end

    def added_by_me_only?
      filter.creators.one? && filter.creators.include?(user)
    end
end
