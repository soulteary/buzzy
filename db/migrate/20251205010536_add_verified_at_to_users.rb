class AddVerifiedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :verified_at, :datetime
  end
end
