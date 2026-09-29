# frozen_string_literal: true

require "test_helper"

class Api::V1::InventoryItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @other_family_user = users(:empty)
    @paper_towels = inventory_items(:paper_towels)
    @coffee_beans = inventory_items(:coffee_beans)
    @frozen_pizza = inventory_items(:frozen_pizza)

    @oauth_app = Doorkeeper::Application.create!(
      name: "Test App",
      redirect_uri: "https://example.com/callback",
      scopes: "read read_write"
    )
    @read_token = Doorkeeper::AccessToken.create!(application: @oauth_app, resource_owner_id: @user.id, scopes: "read")
    @read_write_token = Doorkeeper::AccessToken.create!(application: @oauth_app, resource_owner_id: @user.id, scopes: "read_write")
  end

  test "index requires authentication" do
    get api_v1_inventory_items_url
    assert_response :unauthorized
  end

  test "index returns only the family's items" do
    other = @other_family_user.family.inventory_items.create!(name: "Not mine")

    get api_v1_inventory_items_url, headers: read_headers
    assert_response :success

    ids = JSON.parse(response.body).map { |item| item["id"] }
    assert_includes ids, @paper_towels.id
    assert_not_includes ids, other.id
  end

  test "index filters and rejects unknown filters" do
    travel_to Date.new(2026, 9, 29) do
      @paper_towels.update!(expires_on: Date.new(2026, 9, 1))

      get api_v1_inventory_items_url(filter: "expired"), headers: read_headers
      assert_equal [ @paper_towels.id ], JSON.parse(response.body).map { |item| item["id"] }

      get api_v1_inventory_items_url(filter: "needs_restock"), headers: read_headers
      assert_equal [ @coffee_beans.id ], JSON.parse(response.body).map { |item| item["id"] }
    end

    get api_v1_inventory_items_url(filter: "bogus"), headers: read_headers
    assert_response :unprocessable_entity
  end

  test "summary counts restock, expiring and expired in the family time zone" do
    @family.update!(timezone: "America/Los_Angeles")
    @paper_towels.update!(expires_on: Date.new(2026, 9, 29))
    @frozen_pizza.update!(expires_on: Date.new(2026, 9, 20))

    # 05:00 UTC on Sep 30 is still Sep 29 in Los Angeles
    travel_to Time.utc(2026, 9, 30, 5, 0) do
      get summary_api_v1_inventory_items_url, headers: read_headers
    end
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal "2026-09-29", body["as_of"]
    assert_equal 1, body["restock_count"]
    assert_equal [ @coffee_beans.id ], body["restock"].map { |item| item["id"] }
    assert_equal [ [ @paper_towels.id, 0 ] ], body["expiring_soon"].map { |item| [ item["id"], item["days_left"] ] }
    assert_equal [ @frozen_pizza.id ], body["expired"].map { |item| item["id"] }
    assert_equal 1, body["expired_count"]
  end

  test "increment and decrement need read_write" do
    post increment_api_v1_inventory_item_url(@paper_towels), headers: read_headers
    assert_response :forbidden
    assert_equal 6, @paper_towels.reload.current_qty
  end

  test "increment and decrement adjust stock and never go below zero" do
    post increment_api_v1_inventory_item_url(@paper_towels, by: 2), headers: read_write_headers
    assert_response :success
    assert_equal 8, JSON.parse(response.body)["current_qty"]

    post decrement_api_v1_inventory_item_url(@coffee_beans, by: 5), headers: read_write_headers
    assert_response :success
    assert_equal 0, @coffee_beans.reload.current_qty
  end

  test "cannot change another family's item" do
    other = @other_family_user.family.inventory_items.create!(name: "Not mine", current_qty: 1)

    post decrement_api_v1_inventory_item_url(other), headers: read_write_headers
    assert_response :not_found
    assert_equal 1, other.reload.current_qty
  end

  private

    def read_headers
      { "Authorization" => "Bearer #{@read_token.token}" }
    end

    def read_write_headers
      { "Authorization" => "Bearer #{@read_write_token.token}" }
    end
end
