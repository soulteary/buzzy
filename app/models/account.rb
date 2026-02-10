class Account < ApplicationRecord
  include Account::Storage, Cancellable, Entropic, Incineratable, MultiTenantable, Seedeable

  has_one :join_code, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :boards, dependent: :destroy
  has_many :cards, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :columns, dependent: :destroy
  has_many :entropies, dependent: :destroy
  has_many :exports, class_name: "Account::Export", dependent: :destroy
  has_many :imports, class_name: "Account::Import", dependent: :destroy

  scope :importing, -> { left_joins(:imports).where(account_imports: { status: %i[pending processing failed] }) }
  scope :active, -> { where.missing(:cancellation).and(where.not(id: importing)) }

  # external_account_id is not used for URL; only for compatibility, SAAS signup, and scripts.
  before_create :assign_external_account_id
  after_create :create_join_code

  validates :name, presence: true

  class << self
    def create_with_owner(account:, owner:)
      create!(**account).tap do |account|
        account.users.create!(role: :system, name: "System")
        account.users.create!(**owner.with_defaults(role: :owner, verified_at: Time.current))
      end
    end
  end

  def slug
    "/#{AccountSlug.encode(self)}"
  end

  def account
    self
  end

  def system_user
    users.find_by!(role: :system)
  end

  def active?
    !cancelled? && !importing?
  end

  def importing?
    imports.where(status: %i[pending processing failed]).exists?
  end

  private
    # Used by seeds/SAAS/scripts only; URL resolution uses account id (UUID) only.
    def assign_external_account_id
      self.external_account_id ||= ExternalIdSequence.next
    end
end
