class Mealie::RecipeFood < ApplicationRecord
  self.table_name = "mealie_recipe_foods"

  belongs_to :recipe, class_name: "Mealie::Recipe", foreign_key: :mealie_recipe_id
  belongs_to :food, class_name: "Mealie::Food", foreign_key: :mealie_food_id, optional: true
end
