# frozen_string_literal: true

class AddLocksToBoards < ActiveRecord::Migration[8.0]
  def change
    add_column :boards, :visibility_locked, :boolean, default: false, null: false
    add_column :boards, :edit_locked, :boolean, default: false, null: false
  end
end
