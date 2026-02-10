# frozen_string_literal: true

class AddSoftDeleteToCardsBoardsAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :cards, :deleted_at, :datetime
    add_column :cards, :deleted_by_id, :uuid
    add_index :cards, :deleted_at
    add_index :cards, :deleted_by_id

    add_column :boards, :deleted_at, :datetime
    add_column :boards, :deleted_by_id, :uuid
    add_index :boards, :deleted_at
    add_index :boards, :deleted_by_id

    add_column :accounts, :deleted_at, :datetime
    add_column :accounts, :deleted_by_id, :uuid
    add_index :accounts, :deleted_at
    add_index :accounts, :deleted_by_id
  end
end
