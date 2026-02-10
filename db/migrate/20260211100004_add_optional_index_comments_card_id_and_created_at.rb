# frozen_string_literal: true

# 可选优化：按 card_id + created_at 列表评论时若出现慢查询再启用。
# 见 docs/mysql-performance-checklist.md 第 5.5 节。
class AddOptionalIndexCommentsCardIdAndCreatedAt < ActiveRecord::Migration[8.0]
  def change
    return if connection.adapter_name == "SQLite"
    return if index_exists?(:comments, [ :card_id, :created_at ], name: "index_comments_on_card_id_and_created_at")

    add_index :comments, [ :card_id, :created_at ], name: "index_comments_on_card_id_and_created_at"
  end
end
