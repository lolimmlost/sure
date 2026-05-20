class Inventory::RestocksController < ApplicationController
  def new
    @items = Current.family.inventory_items.alphabetically
    @transactions = recent_transactions
    @selected_transaction = pick_default_transaction
  end

  def create
    @transaction = Current.family.transactions.find(params[:transaction_id])
    selections = params.fetch(:items, {})

    applied = 0
    InventoryItem.transaction do
      Current.family.inventory_items.where(id: selections.keys).find_each do |item|
        entry = selections[item.id.to_s]
        next unless entry && entry[:selected].present?

        qty = entry[:qty].to_i
        next if qty <= 0

        item.restock_from!(@transaction, qty: qty)
        applied += 1
      end
    end

    if applied.positive?
      redirect_to inventory_items_path, notice: t(".applied", count: applied)
    else
      redirect_to new_inventory_restock_path(transaction_id: @transaction.id),
                  alert: t(".no_items_selected")
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to new_inventory_restock_path, alert: t(".transaction_not_found")
  end

  private

    def recent_transactions
      Current.family.transactions
             .includes(:merchant, entry: :account)
             .joins(:entry)
             .where("entries.date >= ?", 30.days.ago.to_date)
             .order("entries.date DESC")
             .limit(50)
    end

    def pick_default_transaction
      claimed_ids = Current.family.inventory_items
                           .where.not(last_transaction_id: nil)
                           .pluck(:last_transaction_id)

      from_params = params[:transaction_id].presence &&
        @transactions.find { |t| t.id == params[:transaction_id] }

      from_params || @transactions.find { |t| !claimed_ids.include?(t.id) } || @transactions.first
    end
end
