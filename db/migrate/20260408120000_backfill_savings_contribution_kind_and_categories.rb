# frozen_string_literal: true

class BackfillSavingsContributionKindAndCategories < ActiveRecord::Migration[7.2]
  def up
    # Step 1: Reclassify funds_movement transactions on the OUTFLOW side of transfers
    # to savings/HSA/CD/money_market accounts as savings_contribution.
    #
    # Safety:
    # - Only updates transactions that are the outflow_transaction of a Transfer
    # - Only where the inflow (destination) account is a non-checking Depository
    # - Skips transactions already set to savings_contribution
    categorizable_subtypes = %w[savings hsa cd money_market]
    quoted_subtypes = categorizable_subtypes.map { |s| connection.quote(s) }.join(", ")

    say_with_time "Reclassifying funds_movement → savings_contribution for transfers to savings accounts" do
      execute <<-SQL.squish
        UPDATE transactions
        SET kind = 'savings_contribution'
        FROM transfers,
             entries AS inflow_entries,
             accounts AS inflow_accounts,
             depositories
        WHERE transactions.id = transfers.outflow_transaction_id
          AND transactions.kind = 'funds_movement'
          AND inflow_entries.entryable_id = transfers.inflow_transaction_id
          AND inflow_entries.entryable_type = 'Transaction'
          AND inflow_accounts.id = inflow_entries.account_id
          AND inflow_accounts.accountable_type = 'Depository'
          AND inflow_accounts.accountable_id = depositories.id
          AND depositories.subtype IN (#{quoted_subtypes})
      SQL
    end

    # Step 2: Backfill category for savings_contribution transactions that have no category.
    # Uses the family's "Savings Contributions" category (all locale variants).
    locale_names = [
      "Savings Contributions",
      "Aportaciones al ahorro",
      "Contributions à l'épargne",
      "Contribucions d'estalvi",
      "Spaarbijdragen",
      "Sparbeiträge"
    ]

    quoted_names = locale_names.map { |n| connection.quote(n) }.join(", ")

    say_with_time "Backfilling category for savings_contribution transactions" do
      execute <<-SQL.squish
        UPDATE transactions
        SET category_id = matched_category.id
        FROM entries, accounts,
          LATERAL (
            SELECT c.id
            FROM categories c
            WHERE c.family_id = accounts.family_id
              AND c.name IN (#{quoted_names})
            ORDER BY c.created_at ASC
            LIMIT 1
          ) AS matched_category
        WHERE transactions.kind = 'savings_contribution'
          AND transactions.category_id IS NULL
          AND entries.entryable_id = transactions.id
          AND entries.entryable_type = 'Transaction'
          AND accounts.id = entries.account_id
      SQL
    end
  end

  def down
    # Revert savings_contribution back to funds_movement
    say_with_time "Reverting savings_contribution → funds_movement" do
      execute <<-SQL.squish
        UPDATE transactions
        SET kind = 'funds_movement'
        WHERE kind = 'savings_contribution'
      SQL
    end
  end
end
