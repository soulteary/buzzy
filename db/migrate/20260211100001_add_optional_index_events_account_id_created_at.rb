# frozen_string_literal: true

# 可选优化：仅当存在按 account_id + created_at 的慢查询时启用。
# 见 docs/mysql-performance-checklist.md 第 5.1 节。
class AddOptionalIndexEventsAccountIdCreatedAt < ActiveRecord::Migration[8.0]
  def change
    return if connection.adapter_name == "SQLite"
    return if index_exists?(:events, [ :account_id, :created_at ], name: "index_events_on_account_id_and_created_at")

    add_index :events, [ :account_id, :created_at ], name: "index_events_on_account_id_and_created_at"
  end
end
