# frozen_string_literal: true

class OperationLog < ApplicationRecord
  ACTIONS = %w[create update destroy].freeze

  belongs_to :account
  belongs_to :board, optional: true
  belongs_to :user, optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :account_id, presence: true

  scope :chronological, -> { order(created_at: :desc) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_board, ->(board_id) { where(board_id: board_id) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  class << self
    def log!(action:, account:, subject: nil, user: nil, board: nil, changes: nil, request_id: nil, ip_address: nil)
      create!(
        action: action.to_s,
        account: account,
        board: board,
        user: user,
        subject: subject,
        changes_payload: changes,
        request_id: request_id,
        ip_address: ip_address
      )
    end
  end
end
