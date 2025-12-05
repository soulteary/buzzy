class Account::JoinCode < ApplicationRecord
  CODE_LENGTH = 12

  belongs_to :account

  scope :active, -> { where("usage_count < usage_limit") }

  before_create :generate_code, if: -> { code.blank? }

  def redeem_if(&block)
    transaction do
      increment!(:usage_count) if block.call(account)
    end
  end

  def active?
    usage_count < usage_limit
  end

  def reset
    generate_code
    self.usage_count = 0
    save!
  end

  private
    def generate_code
      self.code = loop do
        candidate = SecureRandom.base58(CODE_LENGTH).scan(/.{4}/).join("-")
        break candidate unless self.class.exists?(code: candidate)
      end
    end
end
