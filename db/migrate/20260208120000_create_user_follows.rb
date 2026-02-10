# frozen_string_literal: true

class CreateUserFollows < ActiveRecord::Migration[8.1]
  def change
    create_table :user_follows, id: :uuid do |t|
      t.references :follower, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :followee, null: false, type: :uuid, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :user_follows, [ :follower_id, :followee_id ], unique: true
  end
end
