class InventoryItemsController < ApplicationController
  before_action :set_inventory_item, only: %i[edit update destroy increment decrement]

  def index
    @items = Current.family.inventory_items
                    .includes(last_transaction: { entry: :merchant })
                    .alphabetically
    @grouped_items = InventoryItem.by_category(@items)
    @restock_count = @items.count(&:restock?)
  end

  def shopping_list
    @items = Current.family.inventory_items
                    .includes(last_transaction: { entry: :merchant })
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

  private

    def set_inventory_item
      @inventory_item = Current.family.inventory_items.find(params[:id])
    end

    def inventory_item_params
      params.require(:inventory_item).permit(
        :name, :category, :current_qty, :restock_threshold, :notes
      )
    end
end
