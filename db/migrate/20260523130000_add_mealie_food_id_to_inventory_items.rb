class AddMealieFoodIdToInventoryItems < ActiveRecord::Migration[7.2]
  def change
    add_reference :inventory_items, :mealie_food,
                  type: :uuid,
                  foreign_key: { to_table: :mealie_foods, on_delete: :nullify }
  end
end
