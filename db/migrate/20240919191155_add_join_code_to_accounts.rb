class AddJoinCodeToAccounts < ActiveRecord::Migration[8.0]
  def change
    change_table :accounts do |t|
      t.string :join_code, index: { unique: true }
    end
  end
end
