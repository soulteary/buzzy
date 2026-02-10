# frozen_string_literal: true

class AddLocaleToIdentities < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:identities, :locale)
    add_column :identities, :locale, :string, limit: 10
  end

  def down
    remove_column :identities, :locale, if_exists: true
  end
end
