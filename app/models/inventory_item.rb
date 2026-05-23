class InventoryItem < ApplicationRecord
  UNCATEGORIZED_KEY = "__uncategorized__"

  belongs_to :family
  belongs_to :last_transaction, class_name: "Transaction", optional: true
  belongs_to :mealie_food, class_name: "Mealie::Food", optional: true

  attr_accessor :mealie_food_name_input

  before_validation :resolve_mealie_food_from_input

  validates :name, presence: true
  validates :category, length: { maximum: 100 }, allow_blank: true
  validates :current_qty, :restock_threshold,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :alphabetically, -> { order(Arel.sql("LOWER(name) ASC")) }
  scope :needs_restock, -> { where("restock_threshold > 0 AND current_qty <= restock_threshold") }

  def self.by_category(items)
    items.group_by { |item| item.category.presence || UNCATEGORIZED_KEY }
         .sort_by { |key, _| key == UNCATEGORIZED_KEY ? "zzz" : key.downcase }
         .to_h
  end

  def restock?
    restock_threshold.positive? && current_qty <= restock_threshold
  end

  def increment_qty!(by: 1)
    with_lock do
      update!(current_qty: current_qty + by)
    end
  end

  def decrement_qty!(by: 1)
    with_lock do
      update!(current_qty: [ current_qty - by, 0 ].max)
    end
  end

  def restock_from!(transaction, qty:)
    qty = qty.to_i
    return if qty <= 0

    purchased_at = transaction.entry&.date&.to_time || Time.current

    with_lock do
      update!(
        current_qty: current_qty + qty,
        last_purchased_at: purchased_at,
        last_transaction_id: transaction.id,
        last_restock_qty: qty
      )
    end
  end

  def last_transaction_merchant_name
    return nil unless last_transaction
    last_transaction.merchant&.name || last_transaction.entry&.name
  end

  def display_category
    category.presence
  end

  def mapped_to_mealie?
    mealie_food_id.present?
  end

  private
    def resolve_mealie_food_from_input
      return if mealie_food_name_input.nil?
      name = mealie_food_name_input.to_s.strip
      if name.blank?
        self.mealie_food = nil
      else
        match = Mealie::Food.active.where("LOWER(name) = ?", name.downcase).first
        self.mealie_food = match if match
      end
    end
end
