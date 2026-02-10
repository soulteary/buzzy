# frozen_string_literal: true

module Square
  # 全部内容：按账户分模块展示（参考 admin/all_content）。仅展示「设置为公开」（允许所有人访问）的看板及其卡片；
  # 管理员与普通用户在此页面均只能看到公开看板内容。
  # 可通过无账号前缀的 /square/all_content 访问（此时用第一个账号做布局上下文）。
  class AllContentController < ApplicationController
    include AllContentUsersList

    skip_before_action :require_account, only: :index
    before_action :set_account_for_all_content

    def index
      set_users_by_account_for_all_content(admin: false)

      # 仅展示设置为公开（all_access）的看板及其已发布卡片，按更新时间倒序
      @public_boards = Board.joins(:account).merge(Account.active)
        .all_access
        .includes(:creator, :account)
        .order(updated_at: :desc)
      @public_boards_by_account = @public_boards.group_by(&:account_id)

      public_board_ids = @public_boards.map(&:id)
      @public_cards = if public_board_ids.any?
        Card.published
          .where(board_id: public_board_ids)
          .includes(:creator, board: [ :creator, :account ])
          .order(updated_at: :desc).preloaded.limit(500)
      else
        Card.none
      end
      @public_cards_by_account = @public_cards.group_by { |c| c.board.account_id }

      # 「所有人的内容」不展示当前用户创建的内容，仅展示其他人（用户列表已在 set_users_by_account_for_all_content 中排除当前用户）
      if Current.user.present?
        current_user_id = Current.user.id
        @public_boards_by_account = @public_boards_by_account.transform_values { |boards| boards.reject { |b| b.creator_id == current_user_id } }
        @public_cards_by_account = @public_cards_by_account.transform_values { |cards| cards.reject { |c| c.creator_id == current_user_id } }
      end

      # 展示所有活跃账户，确保每个账户（含其他账户）都会出现，其「对所有人可见」内容按上面分组正确展示
      @accounts = Account.active.order(Arel.sql("lower(name)"))

      # 优先展示关注用户的动态：成员、看板、卡片均按「当前用户是否关注创建者」排序，关注的在前
      if Current.user.present?
        followed_ids = Current.user.followed_user_ids.to_set
        @users_by_account = @users_by_account.transform_values { |us| us.sort_by { |u| followed_ids.include?(u.id) ? 0 : 1 } }
        @public_boards_by_account = @public_boards_by_account.transform_values { |boards| boards.sort_by { |b| followed_ids.include?(b.creator_id) ? 0 : 1 } }
        @public_cards_by_account = @public_cards_by_account.transform_values { |cards| cards.sort_by { |c| followed_ids.include?(c.creator_id) ? 0 : 1 } }
      end

      # 用于「创建者与编辑者相同时不展示创建者」：按看板/卡片取最近一条事件的 creator 作为编辑者
      @last_editor_id_by_board = last_editor_ids_for_boards(@public_boards.pluck(:id))
      @last_editor_id_by_card = last_editor_ids_for_cards(@public_cards.pluck(:id))
    end

    private

      def set_account_for_all_content
        # 无 URL 账号时用当前身份的第一个账号做布局/返回链接，不要求必须带账号
        @account = Current.account.presence || Current.identity&.accounts&.active&.first
        if @account.present?
          Current.account = @account
          Current.user = Current.identity&.users&.find_by(account: @account)
        end
        redirect_to main_app.session_menu_path(script_name: nil) if @account.blank? && Current.identity.blank?
      end

      def last_editor_ids_for_boards(board_ids)
        return {} if board_ids.blank?
        ids = board_ids.uniq
        # 每条看板取最近一条事件的 creator_id 作为编辑者
        rows = Event.where(board_id: ids).order(created_at: :desc).pluck(:board_id, :creator_id)
        rows.each_with_object({}) { |(bid, cid), h| h[bid] = cid unless h.key?(bid) }
      end

      def last_editor_ids_for_cards(card_ids)
        return {} if card_ids.blank?
        ids = card_ids.uniq
        rows = Event.where(eventable_type: "Card", eventable_id: ids).order(created_at: :desc).pluck(:eventable_id, :creator_id)
        rows.each_with_object({}) { |(eid, cid), h| h[eid] = cid unless h.key?(eid) }
      end
  end
end
