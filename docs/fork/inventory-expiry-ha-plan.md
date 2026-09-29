# Inventory: expiry, location, and a Home Assistant API — plan

Branch `feature/inventory-expiry-ha`, cut from `pantry-rebased` at `73e63a1d7` (== prod).
All commits carry the `Fork-Topic: inventory` trailer (see `PATCHES.md`).

## Goal
Keep the pantry in Sure (source of truth, linked to transactions and Mealie) and make it useful from
Home Assistant: know what's low, what expires soon, and adjust stock from HA.

## Safety rails
- `origin/main` is prod, auto-deployed by Coolify. **Never push `main` or `pantry-rebased`**; push only
  this feature branch until Juan approves a deploy.
- Prod runs `db:prepare` on boot, so a merged migration runs immediately. Every migration is rehearsed
  on `sure_rehearsal`, a restore of `~/sure-backups/snapshot-20260929-pre-inventory-expiry.dump`.
- Rehearsal found **no pending migrations** in prod; our migration will be the only one to run.
- Repo rule "do not automatically run migrations": migrations run only on the dev/test/rehearsal DBs.

## Baselines (2026-09-29, before any change)
| Suite | Result |
|---|---|
| Minitest: inventory + `test/controllers/api/v1` | 588 runs, 0 failures, **2 errors** (`mealie_foods` missing — Part 0) |
| RSpec/rswag: `spec/requests/api/v1` | 323 examples, **81 failures** (pre-existing: missing fixtures, auth drift) |
| Full `bin/rails test` | run once during Part 0 as the final-gate baseline |

## Part 0 — schema.rb repair (fork fix)
**Problem:** `db/schema.rb` lacks `mealie_foods`, `mealie_recipes`, `mealie_recipe_foods` and
`inventory_items.mealie_food_id`, but its version (2026_08_11) is newer than those migrations. A fresh DB
loads schema.rb and never gets the Mealie tables. This is why the test DB errors.
**Change:** hand-port just those blocks from the prod schema dump (not a full re-dump; see PATCHES.md).
**Dry run / gate:**
1. The schema drift script no longer lists the inventory/Mealie group; every other line is unchanged.
2. A fresh test DB (`db:test:prepare`) has all four tables.
3. The Minitest baseline goes from 2 errors to 0.

## Part A — migration: `expires_on`, `location`
`add_column :inventory_items, :expires_on, :date` and `:location, :string`. Both nullable, no
defaults, no backfill. Reversible via `change`.
**Dry run / gate (on `sure_rehearsal`):**
1. Checksum of all 86 rows (id, name, qty, threshold, last_transaction_id, mealie_food_id) is the same
   before and after `db:migrate`.
2. `db:rollback` succeeds and the checksum still matches.
3. The schema.rb diff is exactly the migration version plus the two column lines.
4. Timing: the migration takes under 1s (metadata-only ALTER).

## Part B — model
- `EXPIRING_SOON_DAYS = 3`
- scopes: `expired` (`expires_on < today`), `expiring_within(days)` (today..today+days)
- predicates: `expired?`, `expiring_soon?`, `days_until_expiry`
- `restock_from!(txn, qty:, expires_on: nil)` sets `expires_on` only when one is given
- `location` validated to 100 chars, like `category`
**Gate:** new model tests pass, and the existing inventory tests are unchanged and green.

## Part C — UI
- Form: a date field for `expires_on`; a `location` text field with a datalist of the family's existing
  locations plus defaults (Pantry, Fridge, Freezer, Garage)
- Row partial: "Expired" (destructive) and "Expires in Nd" (warning) pills; location shown under the name
- Restock form: an optional expiry date per selected line
- Index header: an expiring-soon count next to the restock count
- All strings in `config/locales/views/inventory/en.yml`; `icon` helper only; design-system tokens
**Gate:** controller tests (update with expiry and location; restock with expiry), `erb_lint`, `rubocop`.
Then a manual click-through in the devcontainer on port 3000 against the rehearsal DB, with Juan's OK
before starting a server.

## Part D — API for Home Assistant
`Api::V1::InventoryItemsController`, following `TagsController` conventions:
| Route | Scope | Purpose |
|---|---|---|
| `GET /api/v1/inventory_items` | read | list; `?filter=needs_restock\|expiring\|expired` |
| `GET /api/v1/inventory_items/summary` | read | HA REST sensor payload (below) |
| `POST /api/v1/inventory_items/:id/increment` / `decrement` | read_write | HA buttons, later barcode scans |

Summary payload:
```json
{ "as_of": "2026-09-29", "restock_count": 3, "expiring_soon_count": 2, "expired_count": 0,
  "restock": [{"id": "…", "name": "Milk", "current_qty": 0, "restock_threshold": 1}],
  "expiring_soon": [{"id": "…", "name": "Yogurt", "expires_on": "2026-10-01", "days_left": 2}],
  "expired": [] }
```
**Gate:**
1. Minitest controller tests (auth, scope, family isolation, filters, increment floor at 0).
2. The rswag spec `spec/requests/api/v1/inventory_items_spec.rb` passes, and the rest of the suite still
   has exactly the same 81 failures.
3. `docs/api/openapi.yaml` is regenerated.
4. `brakeman` is clean.

## Final gate (before asking to deploy)
Full `bin/rails test` against the Part 0 baseline, `rubocop`, `erb_lint`, `brakeman`, the rehearsal
migration re-run from a fresh restore, and the PATCHES.md ledger updated.

## Home Assistant (after deploy, separate repo)
Create a Sure API key (read_write) in Settings → API keys. Then add a `rest` sensor on `/summary`
every 10 min, a dashboard card, an "expiring this week" notification, an arrive-home "you're low on X"
announcement via Music Assistant, and later the companion-app barcode scan mapped to item ids, which
calls `increment`/`decrement`.
