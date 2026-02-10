class User < ApplicationRecord
  include Accessor, AllContentList, Assignee, Attachable, Avatar, Configurable, EmailAddressChangeable,
    Mentionable, Named, Notifiable, Role, Searcher, Watcher
  include Timelined # Depends on Accessor

  belongs_to :account
  belongs_to :identity, optional: true
  belongs_to :frozen_by, class_name: "User", optional: true

  validates :name, presence: true
  validates :bio, length: { maximum: 140 }, allow_blank: true
  validate :single_real_user_per_account, on: [ :create, :update ]

  has_many :comments, inverse_of: :creator, dependent: :destroy

  has_many :filters, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy
  has_many :closures, dependent: :nullify
  has_many :pins, dependent: :destroy
  has_many :pinned_cards, through: :pins, source: :card
  has_many :data_exports, class_name: "User::DataExport", dependent: :destroy

  has_many :user_follows, foreign_key: :follower_id, dependent: :destroy
  has_many :followed_users, through: :user_follows, source: :followee
  has_many :reverse_user_follows, foreign_key: :followee_id, class_name: "UserFollow", dependent: :destroy
  has_many :followers, through: :reverse_user_follows, source: :follower

  def following?(user)
    return false if user.blank? || user.id == id
    followed_user_ids.include?(user.id)
  end

  def deactivate
    transaction do
      accesses.destroy_all
      update! active: false, identity: nil
      close_remote_connections
    end
  end

  def setup?
    name != identity.email_address
  end

  def verified?
    verified_at.present?
  end

  def verify
    update!(verified_at: Time.current) unless verified?
  end

  private
    def close_remote_connections
      ActionCable.server.remote_connections.where(current_user: self).disconnect(reconnect: false)
    end

    def single_real_user_per_account
      return if system?
      return if Rails.env.test? # allow multiple users in fixtures for backward compatibility

      other = account.users.where.not(role: :system).where.not(id: id)
      errors.add(:account_id, :single_user_per_account) if other.exists?
    end
end
