class CreateMealieTables < ActiveRecord::Migration[7.2]
  def change
    create_table :mealie_foods, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :external_id, null: false
      t.string :name, null: false
      t.string :plural_name
      t.datetime :external_updated_at
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :mealie_foods, :external_id, unique: true
    add_index :mealie_foods, :deleted_at

    create_table :mealie_recipes, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :external_id, null: false
      t.string :slug, null: false
      t.string :name, null: false
      t.text :description
      t.datetime :external_updated_at
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :mealie_recipes, :external_id, unique: true
    add_index :mealie_recipes, :slug, unique: true
    add_index :mealie_recipes, :deleted_at

    create_table :mealie_recipe_foods, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :mealie_recipe, null: false, foreign_key: true, type: :uuid
      t.references :mealie_food, foreign_key: true, type: :uuid
      t.decimal :quantity, precision: 12, scale: 4
      t.string :unit
      t.text :note
      t.timestamps
    end
    add_index :mealie_recipe_foods, [ :mealie_recipe_id, :mealie_food_id ]
  end
end
