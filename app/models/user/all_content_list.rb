# frozen_string_literal: true

module User::AllContentList
  extend ActiveSupport::Concern

  included do
    # 管理页：展示所有成员（含已冻结），便于执行冻结/解冻
    scope :for_admin_all_content, -> { where.not(role: :system) }
  end

  class_methods do
    # 用于「所有人的内容」/管理所有内容页的用户范围：Square 仅活跃用户，Admin 含已冻结（除 system）
    def scope_for_all_content(admin: false)
      admin ? for_admin_all_content : active
    end

    # 按账户分组的用户列表（用于所有人的内容、管理所有内容）。调用方可在返回的 Hash 上再排除当前用户、按关注排序等。
    def grouped_by_account(scope = nil)
      (scope || active)
        .order(Arel.sql("lower(name)"))
        .includes(:identity, :account)
        .group_by(&:account_id)
    end

    # 与「所有人的内容」一致的可分配用户：管理员/卡片创建者可见全部活跃用户，普通用户仅本看板用户
    def assignable_for_card(card)
      return active unless Current.user.present?
      return active if Current.user.can_administer_card?(card)
      card.board.users.active
    end
  end
end
