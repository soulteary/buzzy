class DropSearchResults < ActiveRecord::Migration[8.1]
  def change
    drop_table :search_results do |t|
      t.timestamps
    end
  end
end
