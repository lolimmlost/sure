require "test_helper"

class InventoryItemTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @paper_towels = inventory_items(:paper_towels)
    @coffee_beans = inventory_items(:coffee_beans)
    @frozen_pizza = inventory_items(:frozen_pizza)
  end

  test "requires name" do
    item = @family.inventory_items.build(name: "")
    assert_not item.valid?
    assert_includes item.errors[:name], "can't be blank"
  end

  test "current_qty and restock_threshold must be non-negative integers" do
    item = @family.inventory_items.build(name: "Test", current_qty: -1)
    assert_not item.valid?

    item.current_qty = 0
    item.restock_threshold = -1
    assert_not item.valid?
  end

  test "restock? true at and below threshold when threshold > 0" do
    assert @coffee_beans.restock?, "qty 1, threshold 3 should need restock"

    @coffee_beans.update!(current_qty: 3)
    assert @coffee_beans.restock?, "at exact threshold should need restock"

    @coffee_beans.update!(current_qty: 4)
    assert_not @coffee_beans.restock?
  end

  test "restock? false when threshold is 0" do
    assert_not @frozen_pizza.restock?, "items without a threshold never appear in shopping list"
  end

  test "decrement_qty! clamps at zero" do
    @frozen_pizza.decrement_qty!(by: 5)
    assert_equal 0, @frozen_pizza.reload.current_qty
  end

  test "restock_from! bumps qty, sets last_purchased_at + last_transaction_id + last_restock_qty" do
    transaction = transactions(:one)
    entry_date = transaction.entry.date

    assert_difference -> { @paper_towels.reload.current_qty }, 3 do
      @paper_towels.restock_from!(transaction, qty: 3)
    end

    @paper_towels.reload
    assert_equal transaction.id, @paper_towels.last_transaction_id
    assert_equal 3, @paper_towels.last_restock_qty
    assert_equal entry_date.to_time, @paper_towels.last_purchased_at
  end

  test "restock_from! is a no-op when qty <= 0" do
    transaction = transactions(:one)
    assert_no_changes -> { @paper_towels.reload.current_qty } do
      @paper_towels.restock_from!(transaction, qty: 0)
      @paper_towels.restock_from!(transaction, qty: -2)
    end
  end

  test "by_category groups items and buckets blank category as uncategorized" do
    blank = @family.inventory_items.create!(name: "Mystery item", category: "")
    grouped = InventoryItem.by_category(@family.inventory_items.alphabetically)

    assert grouped.key?("Toiletries")
    assert grouped.key?("Dry goods")
    assert grouped.key?(InventoryItem::UNCATEGORIZED_KEY)
    assert_includes grouped[InventoryItem::UNCATEGORIZED_KEY], blank
  end

  test "needs_restock scope returns only items at-or-below positive threshold" do
    ids = InventoryItem.needs_restock.pluck(:id)
    assert_includes ids, @coffee_beans.id
    assert_not_includes ids, @paper_towels.id
    assert_not_includes ids, @frozen_pizza.id
  end

  test "expired and expiring_within scopes split on today in the current zone" do
    travel_to Date.new(2026, 9, 29) do
      @paper_towels.update!(expires_on: Date.new(2026, 9, 28))
      @coffee_beans.update!(expires_on: Date.new(2026, 9, 29))
      @frozen_pizza.update!(expires_on: Date.new(2026, 10, 2))
      later = @family.inventory_items.create!(name: "Rice", expires_on: Date.new(2026, 10, 3))

      assert_equal [ @paper_towels.id ], InventoryItem.expired.pluck(:id)
      soon = InventoryItem.expiring_within(3).pluck(:id)
      assert_includes soon, @coffee_beans.id, "expiring today counts as soon, not expired"
      assert_includes soon, @frozen_pizza.id
      assert_not_includes soon, later.id
      assert_not_includes soon, @paper_towels.id
    end
  end

  test "expiry predicates and days_until_expiry" do
    travel_to Date.new(2026, 9, 29) do
      assert_nil @paper_towels.days_until_expiry
      assert_not @paper_towels.expired?
      assert_not @paper_towels.expiring_soon?

      @paper_towels.expires_on = Date.new(2026, 9, 28)
      assert @paper_towels.expired?
      assert_not @paper_towels.expiring_soon?

      @paper_towels.expires_on = Date.new(2026, 10, 2)
      assert_equal 3, @paper_towels.days_until_expiry
      assert @paper_towels.expiring_soon?
      assert_not @paper_towels.expiring_soon?(within: 2)
    end
  end

  test "restock_from! sets expires_on only when given" do
    transaction = transactions(:one)
    @paper_towels.update!(expires_on: Date.new(2026, 10, 1))

    @paper_towels.restock_from!(transaction, qty: 1)
    assert_equal Date.new(2026, 10, 1), @paper_towels.reload.expires_on

    @paper_towels.restock_from!(transaction, qty: 1, expires_on: Date.new(2026, 11, 1))
    assert_equal Date.new(2026, 11, 1), @paper_towels.reload.expires_on
  end
end
