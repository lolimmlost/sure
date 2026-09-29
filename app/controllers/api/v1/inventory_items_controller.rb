# frozen_string_literal: true

module Api
  module V1
    # FORK: pantry inventory for Home Assistant (REST sensor + stock buttons).
    #
    # Dates ("today", days left) are computed in the family's time zone.
    #
    # @example Payload for a Home Assistant REST sensor
    #   GET /api/v1/inventory_items/summary
    #
    # @example Items that are expired
    #   GET /api/v1/inventory_items?filter=expired
    #
    # @example Use one from a Home Assistant button
    #   POST /api/v1/inventory_items/:id/decrement
    class InventoryItemsController < BaseController
      FILTERS = %w[needs_restock expiring expired].freeze
      MAX_STEP = 100

      before_action -> { authorize_scope!(:read) }, only: %i[index summary]
      before_action -> { authorize_scope!(:read_write) }, only: %i[increment decrement]
      around_action :use_family_time_zone
      before_action :set_item, only: %i[increment decrement]

      # List the family's inventory items, optionally filtered
      #
      # @param filter [String] needs_restock, expiring or expired (optional)
      # @return [Array<Hash>] JSON array of inventory items sorted by name
      def index
        filter = params[:filter].presence
        if filter && FILTERS.exclude?(filter)
          return render_validation_error("filter must be one of: #{FILTERS.join(', ')}")
        end

        items = filtered(family.inventory_items.alphabetically, filter)
        render json: items.map { |item| item_json(item) }
      rescue StandardError => e
        Rails.logger.error("API Inventory Items Error: #{e.message}")
        render json: { error: "Failed to fetch inventory items" }, status: :internal_server_error
      end

      # Counts and short lists for dashboards and notifications
      #
      # @return [Hash] restock / expiring_soon / expired counts and items
      def summary
        items = family.inventory_items.alphabetically.to_a
        restock = items.select(&:restock?)
        expiring_soon = items.select(&:expiring_soon?).sort_by(&:expires_on)
        expired = items.select(&:expired?).sort_by(&:expires_on)

        render json: {
          as_of: Date.current,
          expiring_soon_days: InventoryItem::EXPIRING_SOON_DAYS,
          restock_count: restock.size,
          expiring_soon_count: expiring_soon.size,
          expired_count: expired.size,
          restock: restock.map { |item| brief_json(item) },
          expiring_soon: expiring_soon.map { |item| brief_json(item) },
          expired: expired.map { |item| brief_json(item) }
        }
      rescue StandardError => e
        Rails.logger.error("API Inventory Summary Error: #{e.message}")
        render json: { error: "Failed to build inventory summary" }, status: :internal_server_error
      end

      # Add stock
      #
      # @param by [Integer] how many to add (optional, default 1, max 100)
      # @return [Hash] the updated inventory item
      def increment
        @item.increment_qty!(by: step)
        render json: item_json(@item)
      rescue StandardError => e
        Rails.logger.error("API Inventory Increment Error: #{e.message}")
        render json: { error: "Failed to update inventory item" }, status: :internal_server_error
      end

      # Use stock (never goes below zero)
      #
      # @param by [Integer] how many to remove (optional, default 1, max 100)
      # @return [Hash] the updated inventory item
      def decrement
        @item.decrement_qty!(by: step)
        render json: item_json(@item)
      rescue StandardError => e
        Rails.logger.error("API Inventory Decrement Error: #{e.message}")
        render json: { error: "Failed to update inventory item" }, status: :internal_server_error
      end

      private

        def family
          current_resource_owner.family
        end

        def use_family_time_zone(&action)
          Time.use_zone(family&.timezone.presence || Time.zone, &action)
        end

        def set_item
          @item = family.inventory_items.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Inventory item not found" }, status: :not_found
        end

        def filtered(items, filter)
          case filter
          when "needs_restock" then items.needs_restock
          when "expiring" then items.expiring_within(InventoryItem::EXPIRING_SOON_DAYS)
          when "expired" then items.expired
          else items
          end
        end

        def step
          params.fetch(:by, 1).to_i.clamp(1, MAX_STEP)
        end

        def brief_json(item)
          {
            id: item.id,
            name: item.name,
            location: item.location,
            current_qty: item.current_qty,
            restock_threshold: item.restock_threshold,
            expires_on: item.expires_on,
            days_left: item.days_until_expiry
          }
        end

        def item_json(item)
          brief_json(item).merge(
            category: item.category,
            needs_restock: item.restock?,
            expired: item.expired?,
            expiring_soon: item.expiring_soon?,
            last_purchased_at: item.last_purchased_at,
            created_at: item.created_at,
            updated_at: item.updated_at
          )
        end
    end
  end
end
