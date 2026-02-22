class RestoreClassificationColumnOnCategories < ActiveRecord::Migration[7.2]
  def up
    if column_exists?(:categories, :classification_unused)
      rename_column :categories, :classification_unused, :classification
    end
  end

  def down
    if column_exists?(:categories, :classification)
      rename_column :categories, :classification, :classification_unused
    end
  end
end
