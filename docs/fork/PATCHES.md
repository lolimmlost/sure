# Fork patch ledger (lolimmlost/sure)

Everything on our deploy branch that is **not** in `we-promise/sure`. Use this when rebasing onto a
newer upstream: cherry-pick topic by topic, in the order listed, and resolve conflicts per topic.

- Upstream: `upstream` = https://github.com/we-promise/sure.git
- Deploy branch: `origin/main` (Coolify **auto-deploys on push**; `bin/docker-entrypoint` runs
  `db:prepare`, so any migration on `main` runs against prod on the next boot)
- Working branch: `pantry-rebased` (== `origin/main` as of 2026-09-29, `73e63a1d7`)
- Last rebase base: upstream `5accc90a8`. Upstream was 415 commits ahead on 2026-09-29.

## How to find fork commits

```bash
git fetch upstream
git cherry -v upstream/main HEAD            # "+" = fork-only, "-" = already upstream (drop it)
git log --reverse --format='%h %s' --grep='^Fork-Topic: inventory' upstream/main..HEAD
```

From 2026-09-29 on, every fork commit carries a `Fork-Topic: <topic>` trailer, so a topic can be
listed and cherry-picked with the `--grep` above. Older commits are listed by hand below.

## Conflict hotspots (upstream files the fork edits)

| File | Why | Rebase tip |
|---|---|---|
| `db/schema.rb` | fork tables/columns | Never take a full re-dump. Re-apply only the fork blocks listed under **schema.rb fork blocks** |
| `config/routes.rb` | inventory + API routes | New fork routes are marked with a `# FORK:` comment |
| `config/schedule.yml` | `mealie_sync` cron | Append-only |
| `docs/api/openapi.yaml` | inventory paths (generated) | Take upstream's file, re-run `rake rswag:specs:swaggerize`. The committed file lagged upstream specs by 11 hunks on 2026-09-29 |
| `app/models/family.rb` | `has_many :inventory_items` | One line |
| `app/views/layouts/application.html.erb` + `config/locales/views/layout/en.yml` | Inventory nav entry | Small, re-apply by hand |

Fork-only files (`app/**/inventory*`, `app/models/mealie/**`, `config/locales/views/inventory/`,
`docs/fork/`) never conflict.

**Stray file:** one inventory commit also added `.claude/scheduled_tasks.lock`. Drop it when that
commit is next replayed.

## schema.rb fork blocks

**Format:** our `schema.rb` is still `Schema[7.2]`, but the app runs Rails 8.1 and upstream now commits
`Schema[8.1]` (alphabetical columns). A normal `db:schema:dump` rewrites ~1,700 lines. Until the next
rebase, hand-edit `schema.rb` for fork migrations. At the rebase, take upstream's 8.1 file and re-add
the blocks below.

Prod's schema **differs** from `db/schema.rb` (see "Known prod-only schema" below), so on a rebase:
take upstream's `schema.rb`, then re-add only these blocks:

- `inventory_items` (+ `mealie_food_id`, `expires_on`, `location`)
- `mealie_foods`, `mealie_recipes`, `mealie_recipe_foods`, and their foreign keys

## Topics (oldest first; 33 fork commits as of 2026-09-29)

### deploy: Coolify build-from-source
- `980ab2dba` Coolify build-from-source deploy config for compose.example.yml
- *2026-09-29:* `pull_policy: never` on `worker` (Coolify's newer pre-deploy
  `pull --ignore-buildable` otherwise fails on the local-only `sure:${SOURCE_COMMIT}` image)

### imports: Fidelity / Buddy
- `34ffa084f` Add Buddy and Fidelity import types with TwelveData rate limit handling
- `070334c1e` Add positions CSV support to FidelityImport
- `9d3a07482` Add duplicate detection to FidelityImport
- `660645b98` Fix import safeguards: account validation, Fidelity selector, and i18n
- `d0a98f248` Fix Fidelity import: persist positions account selection without re-upload

### investments
- `74010be8c` Fix get_holdings: Security is not scoped to Family *(upstream candidate)*
- `27d8852fc` Fix opening balance trade amount to use cost basis (qty * price) *(upstream candidate)*
- `6d348ad39` Add investment vs crypto breakdown to dashboard summary
- `08cdf4289` Use monetize pattern for investment/crypto breakdown values

### plaid
- `a6cf142d5` PlaidItem: filter ghost sub-accounts via excluded_account_masks
- `ccad38495` Fix new-transaction account dropdown hiding Plaid-linked accounts *(upstream candidate)*

### inventory: pantry, restock, Mealie
- `f725e0e50` Inventory: add pantry/restock tracking tied to transactions
- `1241c0cc4` Mealie: add nightly sync of foods/recipes for pantry matching
- `2b944114c` Inventory: link items to Mealie foods (Phase 2 mapping UI)
- `e796f65c9` Inventory: fix index crash after first restock
- `94389626b` Inventory: rank Mealie food suggestions by confidence not raw token count
- `c0a1da612` Inventory: "What can I make?" recipe finder via Mealie /suggestions
- `541a1c963` Inventory: surface "What can I make?" and Shopping list on mobile
- `cbe57caa3` Inventory: convert local food IDs to Mealie external IDs for /suggestions
- `84fe1ff21` Inventory: add per-recipe "Add missing to shopping list" button
- `8fced7f21` Mealie::Client: use FlatParamsEncoder for repeated query params
- `44e0401d5` Inventory recipes: default max_missing to 10, extend dropdown to 20
- `3d6bf6848` Inventory recipes: fix max-missing dropdown not refreshing
- `e21feb796` Tests: assert response status (not raise) for cross-family inventory access
- *2026-09-29, branch `feature/inventory-expiry-ha` (`Fork-Topic: inventory`; not yet on main):*
  - `0a6531012` Inventory: add missing Mealie tables to schema.rb
  - `dcb2c5f44` Inventory: add expires_on and location columns
  - `de90510a1` Inventory: expiry scopes and predicates on InventoryItem
  - `1d50ae9a2` Inventory: expiry and location in the UI
  - `4df31d09b` Inventory: API for Home Assistant

### prod-reconciliation
- `48b635f51` Safe-deploy reconciliation: back up fork goal tables + rename classification for prod

### fixes (all upstream candidates)
- `a40cedac2` Fix money input: accept high-precision decimal amounts
- `79232ded6` Add rake task to clean up stale pending transaction metadata
- `5210fee52` Fix PWA: back/X buttons untappable in wizard layout (budget edit)
- `cea557a7c` Guard against account reassignment for provider-linked entries
- `a811755fb` Fix duplicate merge deleting transactions due to self-referencing match
- `ecbd82d43` Fix budget FX: use nearest exchange rate when exact date is missing
- `73e63a1d7` Entry: relocate provider-link validation into existing private block

## Known pre-existing test failures (2026-09-29, not fork-inventory related)

- Minitest (6,241 runs): `ImportsControllerTest#test_shows_disabled_account-dependent_imports...`
  (span count) and `Transaction::MergeWithDuplicateTest#test_returns_false_and_does_not_destroy_pending_entry...`
  (conflicts with fork commit `cea557a7c`'s provider-link guard)
- RSpec/rswag `spec/requests/api/v1`: 81 failures across 15 files (missing `users(:empty)` /
  `api_keys(:active_key)` fixtures in RSpec, auth drift)

## Known prod-only schema (intentional; do NOT re-add to schema.rb)

Measured 2026-09-29 by diffing a prod snapshot against `db/schema.rb`. Prod ran 9 migrations whose
files are no longer in the tree (older fork branches):
`goals_fork_backup`, `goal_accounts_fork_backup`, `budget_categories.{goal_id, annual_amount,
budget_frequency}`, `categories.savings`, `trades.{realized_gain*, cost_basis_*, holding_period_days}`,
`accounts.holdings_snapshot_*`, `snaptrade_accounts.account_id`, plus null-constraint differences on
`binance_items`, `ibkr_items`, `ibkr_accounts`. `accounts.account_providers_count` is in `schema.rb`
but not prod (upstream churn, no code reads it).
