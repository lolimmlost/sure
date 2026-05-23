class InventoryItemsController < ApplicationController
  before_action :set_inventory_item, only: %i[edit update destroy increment decrement]

  def index
    @items = Current.family.inventory_items
                    .includes(:mealie_food, last_transaction: [ :merchant, :entry ])
                    .alphabetically
    @grouped_items = InventoryItem.by_category(@items)
    @restock_count = @items.count(&:restock?)
    @unmapped_count = @items.count { |i| !i.mapped_to_mealie? }
  end

  def shopping_list
    @items = Current.family.inventory_items
                    .includes(last_transaction: [ :merchant, :entry ])
                    .needs_restock
                    .alphabetically
  end

  def new
    @inventory_item = Current.family.inventory_items.new
  end

  def create
    @inventory_item = Current.family.inventory_items.new(inventory_item_params)

    if @inventory_item.save
      redirect_to inventory_items_path, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @inventory_item.update(inventory_item_params)
      redirect_to inventory_items_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @inventory_item.destroy!
    redirect_to inventory_items_path, notice: t(".deleted")
  end

  def increment
    @inventory_item.increment_qty!(by: 1)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(helpers.dom_id(@inventory_item), partial: "inventory_items/inventory_item", locals: { item: @inventory_item }) }
      format.html { redirect_to inventory_items_path }
    end
  end

  def decrement
    @inventory_item.decrement_qty!(by: 1)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(helpers.dom_id(@inventory_item), partial: "inventory_items/inventory_item", locals: { item: @inventory_item }) }
      format.html { redirect_to inventory_items_path }
    end
  end

  def recipes
    on_hand_items = Current.family.inventory_items
                                  .includes(:mealie_food)
                                  .where("current_qty > 0")
                                  .where.not(mealie_food_id: nil)
    @food_count = on_hand_items.count
    @mealie_base_url = Rails.configuration.x.mealie.base_url
    @mealie_group_slug = Rails.configuration.x.mealie.group_slug

    if @food_count.zero?
      @suggestions = []
      return
    end

    local_food_ids = on_hand_items.pluck(:mealie_food_id).uniq
    external_food_ids = Mealie::Food.where(id: local_food_ids).pluck(:external_id)
    max_missing = params.fetch(:max_missing, 3).to_i.clamp(0, 10)

    begin
      response = Mealie::Client.new.recipe_suggestions(food_ids: external_food_ids, max_missing: max_missing, limit: 50)
      @suggestions = (response["items"] || []).sort_by { |s| s["missingFoods"].to_a.size }
      @max_missing = max_missing
    rescue Mealie::Client::Error, Mealie::Client::NotConfiguredError => e
      @suggestions = []
      @mealie_error = e.message
    end
  end

  def suggest_mealie_mappings
    @suggestions = Inventory::FoodMatcher.new(family: Current.family).suggestions_for_unmapped
    @available_foods = Mealie::Food.active.order(:name)
  end

  def bulk_apply_mealie_mappings
    pairs = params.fetch(:mappings, {}).to_unsafe_h
    applied = 0
    Current.family.inventory_items.where(id: pairs.keys).find_each do |item|
      food_id = pairs[item.id].presence
      next if food_id.blank?
      next unless Mealie::Food.active.where(id: food_id).exists?
      item.update_column(:mealie_food_id, food_id)
      applied += 1
    end
    redirect_to inventory_items_path, notice: t(".applied", count: applied)
  end

  private

    def set_inventory_item
      @inventory_item = Current.family.inventory_items.find(params[:id])
    end

    def inventory_item_params
      params.require(:inventory_item).permit(
        :name, :category, :current_qty, :restock_threshold, :notes, :mealie_food_name_input
      )
    end
end
