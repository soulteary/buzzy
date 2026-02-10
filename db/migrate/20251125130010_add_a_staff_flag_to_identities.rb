class AddAStaffFlagToIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :identities, :staff, :boolean, null: false, default: false
  end
end
