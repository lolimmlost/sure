# Safe-deploy reconciliation (2026-08-10): the fork restored
# categories.classification (migration 20260331000000) for its savings-budget
# feature, whereas upstream renamed that column to classification_unused and
# dropped all classification logic (income/expense is now derived). The
# rebased branch is upstream-based: its schema and data_importer both use
# classification_unused, so prod's classification column must be renamed to
# match — otherwise SureImport (which writes classification_unused) errors.
#
# Any fork "savings" markers stored in the column are preserved verbatim under
# the new name (dormant; upstream ignores the column). No-op on fresh/upstream
# databases that already have classification_unused.
class RenameCategoriesClassificationToUnusedForUpstream < ActiveRecord::Migration[7.2]
  def up
    if column_exists?(:categories, :classification) && !column_exists?(:categories, :classification_unused)
      rename_column :categories, :classification, :classification_unused
    end
  end

  def down
    if column_exists?(:categories, :classification_unused) && !column_exists?(:categories, :classification)
      rename_column :categories, :classification_unused, :classification
    end
  end
end
