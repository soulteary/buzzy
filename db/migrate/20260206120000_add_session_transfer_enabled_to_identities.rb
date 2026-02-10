# frozen_string_literal: true

class AddSessionTransferEnabledToIdentities < ActiveRecord::Migration[8.0]
  def change
    return if column_exists?(:identities, :session_transfer_enabled)

    add_column :identities, :session_transfer_enabled, :boolean, default: true, null: false
  end
end
