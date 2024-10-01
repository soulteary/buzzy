class AddAccountToTags < ActiveRecord::Migration[8.0]
  def change
    change_table :tags do |t|
      t.references :account, null: true
    end

    Tag.update_all account_id: Account.first.id
    change_column_null :tags, :account_id, false
  end
end
