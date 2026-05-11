class AddExcludedAccountMasksToPlaidItems < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:plaid_items, :excluded_account_masks)
      add_column :plaid_items, :excluded_account_masks, :string, array: true, default: []
    end
  end
end
