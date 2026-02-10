# frozen_string_literal: true

# 将 operation_logs.details（由前一迁移从 changes 重命名而来）改为 changes_payload，避免与 ActiveRecord#changes 冲突导致 DangerousAttributeError
class RenameOperationLogsChangesToPayload < ActiveRecord::Migration[8.0]
  def change
    rename_column :operation_logs, :details, :changes_payload
  end
end
