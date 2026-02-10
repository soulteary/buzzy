# frozen_string_literal: true

class AddBioToUsers < ActiveRecord::Migration[8.0]
  def change
    return if column_exists?(:users, :bio)

    add_column :users, :bio, :text
  end
end
