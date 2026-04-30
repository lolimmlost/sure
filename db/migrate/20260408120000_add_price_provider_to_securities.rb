class AddPriceProviderToSecurities < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :securities, :price_provider, :string unless column_exists?(:securities, :price_provider)
    add_index :securities, :price_provider, algorithm: :concurrently unless index_exists?(:securities, :price_provider)
  end
end
