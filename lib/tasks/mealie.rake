namespace :mealie do
  desc "Sync foods + recipes from Mealie into local cache tables"
  task sync_now: :environment do
    puts "Starting Mealie sync..."
    MealieSyncJob.perform_now
    puts "Done. Foods: #{Mealie::Food.active.count}, Recipes: #{Mealie::Recipe.active.count}, Ingredients: #{Mealie::RecipeFood.count}"
  end
end
