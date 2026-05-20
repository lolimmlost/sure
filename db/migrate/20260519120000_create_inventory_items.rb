class CreateInventoryItems < ActiveRecord::Migration[7.2]
  def change
    create_table :inventory_items, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :category
      t.integer :current_qty, null: false, default: 0
      t.integer :restock_threshold, null: false, default: 0
      t.datetime :last_purchased_at
      t.references :last_transaction, type: :uuid, foreign_key: { to_table: :transactions, on_delete: :nullify }
      t.integer :last_restock_qty
      t.text :notes
      t.timestamps
    end

    add_index :inventory_items, [ :family_id, :category ]
    add_check_constraint :inventory_items, "current_qty >= 0", name: "inventory_items_current_qty_non_negative"
    add_check_constraint :inventory_items, "restock_threshold >= 0", name: "inventory_items_restock_threshold_non_negative"
  end
end
