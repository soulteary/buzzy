# frozen_string_literal: true

class CreateIdentityTransferTokens < ActiveRecord::Migration[8.2]
  def change
    create_table :identity_transfer_tokens, id: :uuid do |t|
      t.references :identity, type: :uuid, null: false, foreign_key: true
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :identity_transfer_tokens, :expires_at
  end
end
