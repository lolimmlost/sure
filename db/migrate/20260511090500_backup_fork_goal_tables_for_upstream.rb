# Safe-deploy reconciliation (2026-08-10): the fork shipped its own simple
# goals + goal_accounts tables before upstream built its superset goals
# feature. Upstream's CreateGoals (20260511100000) does an *unguarded*
# create_table :goals / :goal_accounts, which collides with the fork tables
# already present on prod ("relation goals already exists").
#
# Move the fork tables aside so upstream can create fresh, upstream-shaped
# tables. Fork data is preserved in *_fork_backup for a later data migration
# (goals UI is temporarily backed by empty upstream tables). No-op on fresh
# databases, where these tables do not yet exist at this point in the sequence.
class BackupForkGoalTablesForUpstream < ActiveRecord::Migration[7.2]
  def up
    # Fork shape is detected by the ABSENCE of columns upstream adds later
    # (goals.progress_basis @ 20260625130000, goal_accounts.allocated_amount
    # @ 20260625120000). Guards keep this idempotent and fresh-DB-safe.
    if table_exists?(:goals) && !column_exists?(:goals, :progress_basis)
      rename_table :goals, :goals_fork_backup
    end

    if table_exists?(:goal_accounts) && !column_exists?(:goal_accounts, :allocated_amount)
      rename_table :goal_accounts, :goal_accounts_fork_backup
    end
  end

  def down
    rename_table :goals_fork_backup, :goals if table_exists?(:goals_fork_backup)
    rename_table :goal_accounts_fork_backup, :goal_accounts if table_exists?(:goal_accounts_fork_backup)
  end
end
