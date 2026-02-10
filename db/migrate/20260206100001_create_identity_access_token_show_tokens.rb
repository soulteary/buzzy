# frozen_string_literal: true

class CreateIdentityAccessTokenShowTokens < ActiveRecord::Migration[8.2]
  def change
    create_table :identity_access_token_show_tokens, id: :uuid do |t|
      t.references :access_token, type: :uuid, null: false, foreign_key: { to_table: :identity_access_tokens }
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :identity_access_token_show_tokens, :expires_at
  end
end
