# frozen_string_literal: true

class Identity::TransferToken < ApplicationRecord
  belongs_to :identity

  scope :valid, -> { where("expires_at > ?", Time.current) }

  class << self
    def find_identity_by_token_id(id)
      valid.find_by(id: id)&.identity
    end
  end
end
