# frozen_string_literal: true

# 可选优化：仅当存在按 action 的审计检索且慢查询时启用。
# 见 docs/mysql-performance-checklist.md 第 5.2 节。
# 与 MySQL 一致：SQLite 下也添加该索引，便于双适配器索引对齐（见 docs/sqlite-performance.md）。
# 依赖 operation_logs 表已存在（create_operation_logs 迁移已执行）。
class AddOptionalIndexOperationLogsActionCreatedAt < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:operation_logs)
    return if index_exists?(:operation_logs, [ :action, :created_at ], name: "index_operation_logs_on_action_and_created_at")

    add_index :operation_logs, [ :action, :created_at ], name: "index_operation_logs_on_action_and_created_at"
  end
end
