# frozen_string_literal: true

# 敏感行为审计：删除卡片/看板/账号、冻结用户、锁定看板、数据导出等。
# 与 operation_logs（通用操作流水）互补，用于合规与安全审计。
class SensitiveAuditLog < ApplicationRecord
  ACTIONS = %w[
    card_deleted board_deleted account_deleted
    user_frozen user_unfrozen user_deactivated
    board_visibility_locked board_visibility_unlocked
    board_edit_locked board_edit_unlocked
    account_export_started user_data_export_started
  ].freeze

  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :account_id, presence: true

  scope :chronological, -> { order(created_at: :desc) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :by_action, ->(action) { where(action: action) }

  class << self
    def log!(action:, account:, user: nil, subject: nil, metadata: nil, ip_address: nil)
      create!(
        action: action.to_s,
        account: account,
        user: user,
        subject: subject,
        metadata: metadata,
        ip_address: ip_address || Current.ip_address
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
      Rails.logger.warn("[SensitiveAuditLog] Failed to write log: #{e.message}")
    end
  end
end
