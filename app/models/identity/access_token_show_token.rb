# frozen_string_literal: true

class Identity::AccessTokenShowToken < ApplicationRecord
  self.table_name = "identity_access_token_show_tokens"

  belongs_to :access_token, class_name: "Identity::AccessToken"

  scope :valid, -> { where("expires_at > ?", Time.current) }

  class << self
    def find_access_token_by_show_token_id(id)
      token = valid.find_by(id: id)
      return nil unless token

      token.destroy!
      token.access_token
    end
  end
end
