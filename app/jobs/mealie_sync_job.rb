class MealieSyncJob < ApplicationJob
  queue_as :low_priority

  def perform
    client = Mealie::Client.new
    sync_foods(client)
    sync_recipes(client)
  end

  private
    def sync_foods(client)
      seen = []
      client.each_food do |food|
        record = Mealie::Food.find_or_initialize_by(external_id: food["id"])
        record.assign_attributes(
          name: food["name"],
          plural_name: food["pluralName"],
          external_updated_at: food["updatedAt"],
          deleted_at: nil
        )
        record.save!
        seen << record.id
      end
      Mealie::Food.active.where.not(id: seen).update_all(deleted_at: Time.current)
    end

    def sync_recipes(client)
      seen = []
      client.each_recipe_summary do |summary|
        record = upsert_recipe(client, summary)
        seen << record.id if record
      end
      Mealie::Recipe.active.where.not(id: seen).update_all(deleted_at: Time.current)
    end

    def upsert_recipe(client, summary)
      full = client.recipe(summary["slug"])
      recipe = Mealie::Recipe.find_or_initialize_by(external_id: full["id"])
      recipe.assign_attributes(
        slug: full["slug"],
        name: full["name"],
        description: full["description"],
        external_updated_at: full["updatedAt"],
        deleted_at: nil
      )
      recipe.save!
      replace_ingredients(recipe, full["recipeIngredient"] || [])
      recipe
    rescue Mealie::Client::Error => e
      Rails.logger.warn("MealieSyncJob: failed to fetch recipe '#{summary['slug']}': #{e.message}")
      nil
    end

    def replace_ingredients(recipe, ingredients)
      recipe.recipe_foods.delete_all
      rows = ingredients.map do |ing|
        food_external_id = ing.dig("food", "id")
        unit_name = ing.dig("unit", "name")
        food_id = food_external_id && Mealie::Food.where(external_id: food_external_id).pick(:id)
        {
          mealie_recipe_id: recipe.id,
          mealie_food_id: food_id,
          quantity: ing["quantity"],
          unit: unit_name,
          note: ing["note"],
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      Mealie::RecipeFood.insert_all(rows) if rows.any?
    end
end
