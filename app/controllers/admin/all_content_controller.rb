# frozen_string_literal: true

module Admin
  # 管理所有内容：按账户分模块展示（参考 square/all_content）。管理员可见所有用户、所有看板（含隐藏）、所有卡片。
  class AllContentController < ApplicationController
    include AllContentUsersList

    before_action :require_super_admin
    before_action :set_account_for_layout

    def index
      set_users_by_account_for_all_content(admin: true)
      @boards_by_account = Board.includes(:creator, :account).order(Arel.sql("lower(boards.name)")).group_by(&:account_id)
      @cards_by_account = Card.published.latest.preloaded.includes(:creator, board: [ :creator, :account ]).limit(500).group_by { |c| c.board.account_id }
      @accounts = Account.active.order(Arel.sql("lower(name)"))

      # 管理页不展示当前用户创建的内容，仅展示其他成员/看板/卡片（用户列表已在 set_users_by_account_for_all_content 中排除当前用户）
      if Current.user.present?
        current_user_id = Current.user.id
        @boards_by_account = @boards_by_account.transform_values { |boards| boards.reject { |b| b.creator_id == current_user_id } }
        @cards_by_account = @cards_by_account.transform_values { |cards| cards.reject { |c| c.creator_id == current_user_id } }
      end

      # 用于「创建者与编辑者相同时不展示创建者」：与 square/all_content 一致
      card_ids = @cards_by_account.values.flatten.map(&:id)
      @last_editor_id_by_card = last_editor_ids_for_cards(card_ids)
    end

    private

      def last_editor_ids_for_cards(card_ids)
        return {} if card_ids.blank?
        ids = card_ids.uniq
        rows = Event.where(eventable_type: "Card", eventable_id: ids).order(created_at: :desc).pluck(:eventable_id, :creator_id)
        rows.each_with_object({}) { |(eid, cid), h| h[eid] = cid unless h.key?(eid) }
      end

      def set_account_for_layout
        # 布局/返回链接用当前账户，无则用身份下第一个账户
        @account = Current.account.presence || Current.identity&.accounts&.active&.first
        if @account.present?
          Current.account = @account
          Current.user = Current.identity&.users&.find_by(account: @account)
        end
        if @account.blank? && Current.identity.blank?
          head :unprocessable_entity
          return
        end
      end

      def require_super_admin
        head :forbidden unless super_admin?
      end
  end
end
