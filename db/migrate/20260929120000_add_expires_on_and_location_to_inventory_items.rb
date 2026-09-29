class AddExpiresOnAndLocationToInventoryItems < ActiveRecord::Migration[7.2]
  def change
    add_column :inventory_items, :expires_on, :date
    add_column :inventory_items, :location, :string
  end
end
