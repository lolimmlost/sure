require "test_helper"

class InventoryItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @other_family_user = users(:empty)
    @item = inventory_items(:paper_towels)

    assert_not_equal @user.family_id, @other_family_user.family_id,
      "Test setup error: @other_family_user must belong to a different family"
  end

  test "should get index" do
    get inventory_items_url
    assert_response :success
  end

  test "should get shopping_list" do
    get shopping_list_inventory_items_url
    assert_response :success
  end

  test "should get new" do
    get new_inventory_item_url
    assert_response :success
  end

  test "should create item" do
    assert_difference("InventoryItem.count") do
      post inventory_items_url, params: {
        inventory_item: { name: "Olive oil", category: "Pantry", current_qty: 2, restock_threshold: 1 }
      }
    end
    assert_redirected_to inventory_items_url
  end

  test "should update item" do
    patch inventory_item_url(@item), params: { inventory_item: { name: "Updated name" } }
    assert_redirected_to inventory_items_url
    assert_equal "Updated name", @item.reload.name
  end

  test "should destroy item" do
    assert_difference("InventoryItem.count", -1) do
      delete inventory_item_url(@item)
    end
    assert_redirected_to inventory_items_url
  end

  test "increment bumps qty" do
    assert_difference -> { @item.reload.current_qty }, 1 do
      post increment_inventory_item_url(@item)
    end
  end

  test "decrement drops qty" do
    assert_difference -> { @item.reload.current_qty }, -1 do
      post decrement_inventory_item_url(@item)
    end
  end

  test "cannot access another family's item" do
    sign_in @other_family_user
    post increment_inventory_item_url(@item)
    assert_response :not_found
  end

  test "update saves location and expiry" do
    patch inventory_item_url(@item), params: { inventory_item: { location: "Fridge", expires_on: "2026-10-05" } }
    assert_redirected_to inventory_items_url
    @item.reload
    assert_equal "Fridge", @item.location
    assert_equal Date.new(2026, 10, 5), @item.expires_on
  end

  test "index flags expired and expiring items" do
    travel_to Date.new(2026, 9, 29) do
      @item.update!(expires_on: Date.new(2026, 9, 28), location: "Garage")
      inventory_items(:coffee_beans).update!(expires_on: Date.new(2026, 9, 30))

      get inventory_items_url
      assert_response :success
      assert_select "span", text: /Expired/
      assert_select "span", text: /Expires tomorrow/
      assert_select "span", text: /Garage/
      assert_select "span", text: /2 items are expired or expire within 3 days/
    end
  end
end
