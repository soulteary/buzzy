# frozen_string_literal: true

class AddEventIdToComments < ActiveRecord::Migration[8.0]
  def change
    add_reference :comments, :event, type: :uuid, null: true, index: true, foreign_key: true
  end
end
