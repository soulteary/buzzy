# frozen_string_literal: true

module OperationLoggable
  extend ActiveSupport::Concern

  # 写入 operation_logs.changes_payload 时，字符串超过此长度会被截断，避免 JSON 过大
  TRUNCATE_STRING_LENGTH = 500

  included do
    after_create_commit :operation_log_created
    after_update_commit :operation_log_updated
    after_destroy_commit :operation_log_destroyed
  end

  private
    def operation_log_created
      operation_log_write("create", changes: operation_log_attributes_for_create)
    end

    def operation_log_updated
      operation_log_write("update", changes: previous_changes.except("updated_at"))
    end

    def operation_log_destroyed
      operation_log_write("destroy", changes: operation_log_attributes_for_destroy)
    end

    def operation_log_write(action, changes: nil)
      return unless operation_log_account.present?

      truncated = operation_log_truncate_changes(changes) if changes.present?
      OperationLog.log!(
        action: action,
        account: operation_log_account,
        board: operation_log_board,
        user: Current.user,
        subject: self,
        changes: truncated,
        request_id: Current.request_id,
        ip_address: Current.ip_address
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
      Rails.logger.warn("[OperationLog] Failed to write log: #{e.message}")
    end

    def operation_log_account
      return account if respond_to?(:account) && account.present?
      return board.account if respond_to?(:board) && board.present?
      nil
    end

    def operation_log_board
      return self if is_a?(Board)
      return board if respond_to?(:board) && board.present?
      return card.board if respond_to?(:card) && card.present?
      nil
    end

    def operation_log_attributes_for_create
      operation_log_safe_attributes.transform_values { |v| [ nil, v ] }
    end

    def operation_log_attributes_for_destroy
      operation_log_safe_attributes.transform_values { |v| [ v, nil ] }
    end

    def operation_log_safe_attributes
      return {} unless respond_to?(:attributes)
      raw = attributes.slice(*self.class.column_names).except("id", "created_at", "updated_at")
      operation_log_truncate_values(raw)
    end

    def operation_log_truncate_values(hash)
      hash.transform_values do |v|
        if v.is_a?(String) && v.length > TRUNCATE_STRING_LENGTH
          "#{v[0...(TRUNCATE_STRING_LENGTH - 3)]}..."
        else
          v
        end
      end
    end

    # previous_changes 和 safe_attributes 可能含 [old, new] 或单值，统一截断长字符串
    def operation_log_truncate_changes(changes)
      return nil if changes.blank?
      changes.transform_values do |v|
        case v
        when String
          v.length > TRUNCATE_STRING_LENGTH ? "#{v[0...(TRUNCATE_STRING_LENGTH - 3)]}..." : v
        when Array
          v.map { |x| x.is_a?(String) && x.length > TRUNCATE_STRING_LENGTH ? "#{x[0...(TRUNCATE_STRING_LENGTH - 3)]}..." : x }
        else
          v
        end
      end
    end
end
