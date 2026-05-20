require "test_helper"

class Inventory::RestocksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @paper_towels = inventory_items(:paper_towels)
    @coffee_beans = inventory_items(:coffee_beans)
    @transaction = transactions(:one)
  end

  test "should get new" do
    get new_inventory_restock_url
    assert_response :success
  end

  test "create applies restock to selected items" do
    assert_difference -> { @paper_towels.reload.current_qty }, 2 do
      post inventory_restock_url, params: {
        transaction_id: @transaction.id,
        items: {
          @paper_towels.id => { selected: "1", qty: "2" },
          @coffee_beans.id => { selected: "", qty: "5" }
        }
      }
    end

    @paper_towels.reload
    assert_equal @transaction.id, @paper_towels.last_transaction_id
    assert_equal 2, @paper_towels.last_restock_qty

    assert_equal 1, @coffee_beans.reload.current_qty, "unselected item should not change"
    assert_redirected_to inventory_items_url
  end

  test "create with no selections redirects back with alert" do
    post inventory_restock_url, params: {
      transaction_id: @transaction.id,
      items: { @paper_towels.id => { selected: "", qty: "0" } }
    }
    assert_redirected_to new_inventory_restock_url(transaction_id: @transaction.id)
    assert_not_nil flash[:alert]
  end

  test "cannot restock from another family's transaction" do
    other_user = users(:empty)
    sign_in other_user
    post inventory_restock_url, params: {
      transaction_id: @transaction.id,
      items: {}
    }
    assert_redirected_to new_inventory_restock_url
    assert_not_nil flash[:alert]
  end
end
