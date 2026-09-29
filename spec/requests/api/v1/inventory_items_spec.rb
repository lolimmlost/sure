# frozen_string_literal: true

require 'swagger_helper'

# FORK: pantry inventory for Home Assistant. Schemas are defined inline (not in
# swagger_helper.rb) so the fork does not touch an upstream file.
RSpec.describe 'API V1 Inventory Items', type: :request do
  brief_item_schema = {
    type: :object,
    properties: {
      id: { type: :string, format: :uuid },
      name: { type: :string },
      location: { type: :string, nullable: true },
      current_qty: { type: :integer },
      restock_threshold: { type: :integer },
      expires_on: { type: :string, format: :date, nullable: true },
      days_left: { type: :integer, nullable: true, description: 'Days until expiry in the family time zone; negative once expired' }
    },
    required: %w[id name current_qty restock_threshold]
  }

  item_schema = {
    type: :object,
    properties: brief_item_schema[:properties].merge(
      category: { type: :string, nullable: true },
      needs_restock: { type: :boolean },
      expired: { type: :boolean },
      expiring_soon: { type: :boolean },
      last_purchased_at: { type: :string, format: 'date-time', nullable: true },
      created_at: { type: :string, format: 'date-time' },
      updated_at: { type: :string, format: 'date-time' }
    ),
    required: %w[id name current_qty restock_threshold needs_restock expired expiring_soon]
  }

  let(:family) do
    Family.create!(name: 'API Family', currency: 'USD', locale: 'en', date_format: '%m-%d-%Y')
  end

  let(:user) do
    family.users.create!(email: 'api-user@example.com', password: 'password123', password_confirmation: 'password123')
  end

  let(:api_key) do
    ApiKey.create!(user: user, name: 'API Docs Key', key: ApiKey.generate_secure_key, scopes: %w[read_write], source: 'web')
  end

  let(:'X-Api-Key') { api_key.plain_key }

  let!(:milk) do
    family.inventory_items.create!(name: 'Milk', category: 'Dairy', location: 'Fridge',
                                   current_qty: 0, restock_threshold: 1, expires_on: Date.current + 2)
  end

  let!(:rice) do
    family.inventory_items.create!(name: 'Rice', category: 'Dry goods', location: 'Pantry', current_qty: 3)
  end

  path '/api/v1/inventory_items' do
    get 'List inventory items' do
      tags 'Inventory'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'
      parameter name: :filter, in: :query, required: false,
                schema: { type: :string, enum: %w[needs_restock expiring expired] },
                description: 'Only items that need restock, expire within 3 days, or are expired'

      response '200', 'inventory items listed' do
        schema type: :array, items: item_schema

        run_test!
      end

      response '422', 'unknown filter' do
        let(:filter) { 'bogus' }

        run_test!
      end
    end
  end

  path '/api/v1/inventory_items/summary' do
    get 'Inventory summary (for Home Assistant sensors)' do
      tags 'Inventory'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'

      response '200', 'summary returned' do
        schema type: :object,
               properties: {
                 as_of: { type: :string, format: :date },
                 expiring_soon_days: { type: :integer },
                 restock_count: { type: :integer },
                 expiring_soon_count: { type: :integer },
                 expired_count: { type: :integer },
                 restock: { type: :array, items: brief_item_schema },
                 expiring_soon: { type: :array, items: brief_item_schema },
                 expired: { type: :array, items: brief_item_schema }
               },
               required: %w[as_of restock_count expiring_soon_count expired_count restock expiring_soon expired]

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['restock_count']).to eq(1)
          expect(body['expiring_soon'].map { |item| item['name'] }).to eq([ 'Milk' ])
        end
      end
    end
  end

  %w[increment decrement].each do |action|
    path "/api/v1/inventory_items/{id}/#{action}" do
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :by, in: :query, required: false, schema: { type: :integer, minimum: 1, maximum: 100 },
                description: 'How many to add or remove (default 1)'

      post(action == 'increment' ? 'Add stock' : 'Use stock (floors at zero)') do
        tags 'Inventory'
        security [ { apiKeyAuth: [] } ]
        produces 'application/json'

        response '200', 'item updated' do
          let(:id) { rice.id }
          schema item_schema

          run_test!
        end

        response '404', 'item not found' do
          let(:id) { SecureRandom.uuid }

          run_test!
        end
      end
    end
  end
end
