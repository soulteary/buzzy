# frozen_string_literal: true

# 可选优化：按 board_id + number 查卡片时若出现慢查询再启用。
# 见 docs/mysql-performance-checklist.md 第 5.5 节。
class AddOptionalIndexCardsBoardIdAndNumber < ActiveRecord::Migration[8.0]
  def change
    return if connection.adapter_name == "SQLite"
    return if index_exists?(:cards, [ :board_id, :number ], name: "index_cards_on_board_id_and_number")

    add_index :cards, [ :board_id, :number ], name: "index_cards_on_board_id_and_number"
  end
end
