# frozen_string_literal: true

# 软删除：destroy 时只设置 deleted_at/deleted_by_id，不物理删除。
# 需在表上有 deleted_at (datetime)、deleted_by_id (uuid) 字段。
# 真正物理删除用 real_destroy（如账户注销后的彻底清理）。
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :kept, -> { where(deleted_at: nil) }
    scope :discarded, -> { where.not(deleted_at: nil) }
    default_scope { kept } if column_names.include?("deleted_at")

    belongs_to :deleted_by, class_name: "User", optional: true
    alias_method :ar_destroy, :destroy
  end

  def discarded?
    deleted_at.present?
  end

  def kept?
    !discarded?
  end

  # 软删除：写操作流水与敏感审计，然后只标记 deleted_at，不执行 DELETE。
  def destroy
    return ar_destroy unless self.class.column_names.include?("deleted_at")
    if Thread.current[:soft_deletable_real_destroy]
      return ar_destroy
    end
    return if discarded?

    account = soft_deletable_account
    SensitiveAuditLog.log!(
      action: soft_deletable_audit_action,
      account: account,
      user: Current.user,
      subject: self,
      ip_address: Current.ip_address
    )
    operation_log_write_destroy
    soft_delete!
  end

  # 物理删除（执行原始 AR destroy 与级联），用于如账户注销后的彻底清理。
  def real_destroy
    Thread.current[:soft_deletable_real_destroy] = true
    ar_destroy
  ensure
    Thread.current[:soft_deletable_real_destroy] = false
  end

  private

    def soft_delete!
      update_columns(
        deleted_at: Time.current,
        deleted_by_id: Current.user&.id
      )
    end

    def soft_deletable_account
      return account if respond_to?(:account) && account.present?
      return board.account if respond_to?(:board) && board.present?
      nil
    end

    # 子类覆盖，返回 SensitiveAuditLog 的 action 名，如 "card_deleted"
    def soft_deletable_audit_action
      raise NotImplementedError, "#{self.class} must define soft_deletable_audit_action"
    end

    def operation_log_write_destroy
      return unless account = soft_deletable_account

      attrs = try(:operation_log_safe_attributes) || attributes.slice(*self.class.column_names).except("id", "created_at", "updated_at", "deleted_at", "deleted_by_id")
      changes = attrs.transform_values { |v| [ v, nil ] }
      OperationLog.log!(
        action: "destroy",
        account: account,
        board: try(:board) || (self if is_a?(Board)),
        user: Current.user,
        subject: self,
        changes: changes,
        request_id: Current.request_id,
        ip_address: Current.ip_address
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
      Rails.logger.warn("[OperationLog] Failed to write destroy log: #{e.message}")
    end
end
