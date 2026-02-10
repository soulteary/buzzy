# frozen_string_literal: true

class UserFollow < ApplicationRecord
  belongs_to :follower, class_name: "User"
  belongs_to :followee, class_name: "User"

  validates :followee_id, uniqueness: { scope: :follower_id }
  validate :cannot_follow_self

  private

    def cannot_follow_self
      errors.add(:followee_id, :cannot_follow_self) if follower_id.present? && follower_id == followee_id
    end
end
