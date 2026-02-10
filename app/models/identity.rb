class Identity < ApplicationRecord
  include Joinable, Transferable

  has_many :access_tokens, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :transfer_tokens, class_name: "Identity::TransferToken", dependent: :destroy
  has_many :users, dependent: :nullify
  has_many :accounts, through: :users

  has_one_attached :avatar

  before_destroy :deactivate_users, prepend: true
  after_update :revoke_transfer_tokens, if: :saved_change_to_session_transfer_enabled?

  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  normalizes :email_address, with: ->(value) { value.strip.downcase.presence }
  normalizes :locale, with: ->(value) { value.presence&.strip }

  # 按邮箱前缀（@ 前部分）查找，不区分大小写
  def self.by_email_prefix(prefix)
    return none if prefix.blank?
    handle = prefix.to_s.strip.downcase
    return none if handle.blank?
    case connection.adapter_name
    when /mysql|trilogy/i
      where("LOWER(TRIM(SUBSTRING_INDEX(email_address, '@', 1))) = ?", handle)
    when /postgresql/i
      where("LOWER(TRIM(SPLIT_PART(email_address, '@', 1))) = ?", handle)
    else
      # SQLite 等: SUBSTR(x, 1, INSTR(x||'@', '@') - 1) 为 @ 前部分
      where("LOWER(TRIM(SUBSTR(email_address, 1, INSTR(email_address || '@', '@') - 1))) = ?", handle)
    end
  end

  def self.find_by_permissable_access_token(token, method:)
    if (access_token = AccessToken.find_by(token: token)) && access_token.allows?(method)
      access_token.identity
    end
  end

  def send_magic_link(**attributes)
    attributes[:purpose] = attributes.delete(:for) if attributes.key?(:for)

    magic_links.create!(attributes).tap do |magic_link|
      MagicLinkMailer.sign_in_instructions(magic_link).deliver_later
    end
  end

  private
    def deactivate_users
      users.find_each(&:deactivate)
    end

    def revoke_transfer_tokens
      return if session_transfer_enabled?

      transfer_tokens.delete_all
    end
end
