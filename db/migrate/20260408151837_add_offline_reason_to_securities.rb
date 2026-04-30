class AddOfflineReasonToSecurities < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :securities, :offline_reason, :string unless column_exists?(:securities, :offline_reason)
    add_index :securities, [ :price_provider, :offline_reason ], algorithm: :concurrently unless index_exists?(:securities, [ :price_provider, :offline_reason ])
  end
end
