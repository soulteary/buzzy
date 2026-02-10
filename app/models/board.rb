class Board < ApplicationRecord
  include Accessible, AutoPostponing, Board::Storage, Broadcastable, Cards, Entropic, Filterable,
    OperationLoggable, Publishable, ::Storage::Tracked, Triageable

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { creator.account }
  belongs_to :visibility_locked_by, class_name: "User", optional: true
  belongs_to :edit_locked_by, class_name: "User", optional: true

  has_rich_text :public_description

  has_many :tags, -> { distinct }, through: :cards
  has_many :events
  has_many :webhooks, dependent: :destroy

  scope :alphabetically, -> { order("lower(name)") }
  scope :ordered_by_recently_accessed, -> { merge(Access.ordered_by_recently_accessed) }

  # 管理员可锁定看板可见性，锁定后普通用户无法修改「对所有人可见」开关
  # 管理员可锁定看板可编辑性，锁定后普通用户无法修改看板及卡片
  def editable_by?(user)
    return false if user.blank?
    return true if Buzzy.admin_emails.include?(user.identity&.email_address.to_s.strip.downcase)
    !edit_locked?
  end

  # 仅创建者可修改「对所有人可见」；管理员邮箱可绕过 visibility_locked 锁定
  def visibility_changeable_by?(user)
    return false if user.blank?
    return false unless user == creator
    return true if Buzzy.admin_emails.include?(user.identity&.email_address.to_s.strip.downcase)
    !visibility_locked?
  end

  # 用于生成看板/卡片规范 URL 的用户（/users/:id/boards/...）；统一用 creator，便于旧链接 301 与链接生成一致
  def url_user
    creator
  end
end
