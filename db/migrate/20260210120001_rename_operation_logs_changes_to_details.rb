# frozen_string_literal: true
# 列名 changes 与 ActiveRecord 保留方法冲突，导致 DangerousAttributeError，改为 details。
class RenameOperationLogsChangesToDetails < ActiveRecord::Migration[8.0]
  def change
    rename_column :operation_logs, :changes, :details
  end
end
