module User::Role
  extend ActiveSupport::Concern

  included do
    enum :role, %i[ owner admin member system ].index_by(&:itself), scopes: false

    scope :owner, -> { where(active: true, role: :owner) }
    scope :admin, -> { where(active: true, role: %i[ owner admin ]) }
    scope :member, -> { where(active: true, role: :member) }
    scope :active, -> { where(active: true, role: %i[ owner admin member ]) }

    def admin?
      super || owner?
    end
  end

  def can_change?(other)
    (admin? && !other.owner?) || other == self
  end

  def can_administer?(other)
    admin? && !other.owner? && other != self
  end

  # 单用户账户内：当前用户即全权，可管理账户下所有看板；否则仅看板创建者可访问设置页、修改成员与可见性、删除看板
  def can_administer_board?(board)
    return true if account_id == board.account_id && account_single_user?
    board.creator == self
  end

  # 单用户账户内：当前用户即全权，可管理账户下所有卡片；否则管理员或卡片创建者可管理
  def can_administer_card?(card)
    return true if account_id == card.account_id && account_single_user?
    admin? || card.creator == self
  end

  # 多账户单用户：当前账户除 system 外仅有一名真实用户
  def account_single_user?
    account.users.active.where.not(role: :system).one?
  end
end
