# Collection Showcase — TODO

## Critical — do first after MCP restart
- [x] **Restored wiped Hololive transaction** (2026-04-12) — direct BQ INSERT via REST API with composite `product_id=sealed:hololive:hl01:booster-display` (12 × $56, 2026-02-01, buy); triggered `collection-showcase-data-sync` Cloud Run job; verified BQ + GCS + GitHub all show the row (transaction_id `45fba8c2-3091-4ea6-9c38-6cf75a59b807`). Note: GCS/GitHub sync writes to bucket/repo root (`transactions.json`), not `data/transactions.json`.
- [x] **Guarded `cmd/setup/main.go` against data loss** (2026-04-12) — transactions table now uses same safe "create, 409→update schema" pattern as box_breaks/box_break_pulls/price_history. Rare destructive schema changes (renames) now require a one-off manual step, which is the safer default.
- [ ] **Verify MCP hang fix after server restart** — changes live on disk in `collection-showcase-mcp/server.py` and `collection-market-tracker-mcp/server.py` (ThreadPoolExecutor-bounded `@with_timeout()` on every tool; per-RPC `timeout=` on GCP SDK calls; GCS client singleton). Not effective until subprocesses respawn (`/mcp` reconnect or new Claude session). Smoke test: call `mcp__gcp-collection-tracker__bq_query` with a trivial query; should complete in <5s or return a timeout error, never hang.

## Box Break feature — backend shipped, not yet deployed
Backend code merged and compiles (2026-04-12). BQ tables + view live (setup ran). Next:
- [x] **Deployed backend to Cloud Run** (2026-04-12) — version 1.0.12 live; `/box-breaks` responds with `[]`; CI build+deploy succeeded in 2m44s.
- [ ] **Smoke test box break flow via UI** — pages built (2026-04-12) but not yet exercised end-to-end. Plan: run `hugo server`, sign in, Add Break (pick sealed, date, market value) → redirects to view → Edit pulls (add a few singles + a bulk row) → Save. Verify `inventory.collection` view reflects synthetic sealed-sell + singles-buys; verify `box-breaks/index.json` + `box-breaks/{id}.json` appear in GCS + data repo.
- [x] **Frontend UI for box breaks — MVP** (2026-04-12) — built:
  - `content/box-breaks/_index.md` + `themes/showcase/layouts/box-breaks/list.html` — list w/ sealed image, P&L summary, Create modal (sealed product dropdown filtered from products.json), delete button
  - `content/box-breaks/view/_index.md` + `themes/showcase/layouts/box-breaks/view/list.html` — break header, pulls table, admin pulls editor (add single w/ searchable product picker, add bulk, live allocation preview), PUT /box-breaks/:id/pulls
  - Navbar link (always-visible, like Binders/Shelves)
- [ ] **"Mark as Ripped → Create Box Break" on sealed product detail page** — deferred; no sealed product detail page exists yet. Would need `/products/view/?id=…` or similar before this button has a home.
- [ ] **Bulk sales (deferred)** — box break pulls of type "bulk" track cost basis but have no sell path yet. Needs a `box_break_bulk_sales` table and break-level revenue tracking.

## Up Next
- [ ] **Collection page — show location (display/binder/unorganized)** — JOIN collection with display items + binder slots to show where each owned product is placed; compare owned qty vs placed qty to compute "unorganized" count; update collection.json syncer and frontend
- [x] **Include singles in products.json** (2026-04-03) — syncer now includes all catalog_products (sealed + cards)
- [x] **Filterable product picker on transactions page** (2026-04-03) — searchable type-ahead with game/type filters, replaces plain dropdown
- [x] **Products → Transactions interlink** (2026-04-03) — drill-down products page with "Transaction" button per row; transactions page supports ?product_id= pre-selection
- [ ] Test binder/display UI — create first binder + display via admin (backend is now live with routes)
- [ ] Validate pull rate calculator — confirm p50/p75/p90 and all 3 calc tabs render correctly for Pokemon SV sets in admin; check ace_spec_rare rows (mds=null, may be missing unique_card_count) show graceful — fallback
- [ ] Build set difficulty dashboard — `catalog.set_pull_rates` now has 258 Pokemon rows + 16 Lorcana rows; showcase p50/p75/p90 packs-to-complete across sets and eras

## Backlog

### Box Break — MTG Jumpstart themed half-deck pulls
- [x] **Avatar (tla) Jumpstart themes live** (2026-04-13) — 66 themes (13 × W/U/B/R/G + 1 Multicolor) now exist as `sealed_products` rows with product_type `jumpstart-theme-<slug>-<color>`, surfacing through `inventory.catalog_products` as `sealed:mtg:tla:jumpstart-theme-*`. Source of truth for names + decklists is `collection-market-tracker-frontend-admin/data/jumpstart-decks.json`; no new catalog table needed. Seed script: `collection-market-tracker-backend/scripts/catalog/bulk_insert_mtg_jumpstart_themes.py`. Triggered `collection-showcase-data-sync` Cloud Run job — products.json on GCS + GitHub contains all 66 themes.
- [x] **Frontend Jumpstart-aware picker + quick-fill** (2026-04-13) — `themes/showcase/layouts/box-breaks/view/list.html`: when the break's sealed product matches `sealed:*:*:jumpstart-booster-box`, the product picker auto-filters to that set's `jumpstart-theme-*` entries (with an "All products" toggle in the picker modal to break out), and a "Quick-fill [N]" button (default 24) appears on the editor toolbar to pre-add N empty `single` rows.
- [ ] **Smoke test end-to-end** — not yet exercised in-browser. Plan: create a new box break for Avatar Jumpstart Booster Box, click Edit pulls, click Quick-fill (24), use picker to assign Jumpstart themes to each row, enter MV estimates, Save. Verify allocated cost basis sums to sealed MV.
- [ ] **Fix `jumpstart-booster-box` display name** — products.json currently shows "Universes Beyond jumpstart booster box" (derived from era+product_type because name is NULL). Populate `name` on the existing tla jumpstart-booster-box row in `catalog.sealed_products` — e.g. "Avatar Jumpstart Booster Box".
- [ ] **Theme images** — themes currently have no image_url (TCGPlayer has no individual listing for Jumpstart themes). Could derive from color (5 color-coded placeholders) or skip.
- [ ] **Theme EV from decklists** — `jumpstart-decks.json` has 15-card lists per theme; the admin-side EV pipeline already uses it. Not yet surfaced as `market_value_per_unit` in the box break flow — admin enters MV manually today. Could auto-suggest MV by summing TCGPlayer prices × qty from the decklist; defer.
- [ ] **Other Jumpstart sets** — `SET_METADATA` in the seed script only has `tla`. Add entries for any future MTG Jumpstart sets before re-running.

### Architecture — Major: Migrate source of truth from BigQuery to homelab Postgres
**Status:** planning only, not started. Flip the pipeline so Postgres (homelab) is the OLTP source of truth and BigQuery becomes an incremental backup / analytics warehouse. Multi-week effort spanning all three backend repos.

Phased plan (do in order — no backend changes until PG is fully populated):

**Phase 0 — decisions to lock in first**
- [ ] Pick tunnel: Tailscale (simplest for homelab), Cloud VPN, or IAP TCP forwarding. Default recommendation: Tailscale.
- [ ] Pick Postgres version (default: PG 16) and enable `wal_level=logical` from day one so Datastream CDC is an option later.
- [ ] Homelab backup strategy for PG itself — nightly `pg_dump` → GCS (separate from the BQ-as-backup story).
- [ ] Audit every BQ table we plan to sync: must have a stable primary key + monotonic `updated_at`. Tables to audit: `catalog.sealed_products`, `catalog.single_cards`, `catalog.set_pull_rates`, `market_data.tcgplayer_price_history`, `inventory.transactions`, `inventory.binders`, `inventory.binder_slots`, `inventory.showcase_displays`, `inventory.showcase_display_items`, `inventory.box_breaks`, `inventory.box_break_pulls`. Add missing columns in BQ first — retrofitting mid-migration is painful.

**Phase 1 — stand up Postgres on homelab**
- [ ] Install PG 16, enable logical replication, set up Tailscale on homelab + Cloud Run sidecar.
- [ ] Create roles: `app_rw` (backends), `sync_ro` (BQ export job), `migrator`.
- [ ] Introduce a migration tool (`goose` or `atlas`) in `collection-market-tracker-backend` under `sql/`. No hand-run DDL.
- [ ] Smoke test: a Cloud Run job can connect over Tailscale and `SELECT 1`.

**Phase 2 — mirror BQ → PG (initial backfill + ongoing sync)**
- [ ] One-shot backfill: BQ `EXPORT DATA` → GCS Parquet → `COPY` into PG.
- [ ] Ongoing mirror: new Cloud Run job (hourly) does watermark-based `SELECT * FROM bq WHERE updated_at > :watermark` → upsert into PG. Watermark state stored in a PG table.
- [ ] Run for ≥1 week before touching backends. Monitor for type drift (BQ `NUMERIC` vs PG `numeric`, timestamps, JSON columns).

**Phase 3 — switch backends to read from PG (least-risky first)**
- [ ] Showcase data-sync job first — swap BQ client → `pgx`. Only writes JSON; if it breaks, site goes stale, no data loss.
- [ ] Market-tracker backend API **read** paths → PG. Writes still go to BQ.
- [ ] Market-tracker backend API **write** paths → PG. **Cutover moment.** Stop the Phase 2 mirror.
- [ ] Price scraper job (`tcgplayer-price-scraper`) last — highest-volume writer. Add retry/backoff + local queue before flipping.

**Phase 4 — reverse sync: PG → BQ as backup**
- [ ] Start with Option A: Cloud Run job every N minutes, `updated_at` watermark, upsert into BQ via MERGE.
- [ ] Upgrade to Option B (Datastream for PostgreSQL → BQ CDC) only if deletes need to be captured.

**Phase 5 — cleanup**
- [ ] Remove BQ write paths from backend + scraper.
- [ ] Keep BQ read access for ad-hoc analytics.
- [ ] Document new tunnel + failure modes in `CLAUDE.md`.

**Risks to name up front**
- Tunnel outage = everything stops. Scraper retry/backoff is non-negotiable.
- Homelab power/network blips are now in the critical write path.
- Type fidelity between BQ and PG will bite once — budget a day for it.

### Market Tracker — Data Sync
- [x] **Fixed stale `set-pull-rates.json` on GCS/GitHub** (2026-03-29) — root cause: bulk Python insert went directly to BQ, bypassing the API auto-sync. Fix: wrote `scripts/catalog/sync_catalog.py` (BQ -> GCS -> GitHub for any catalog table); added sync call to end of `bulk_insert_pokemon_pull_rates.py`; ran manual sync → 274 rows now live on GCS + GitHub (`collection-market-tracker-data@d359742`).

### Market Tracker — Pricing & Scraper Job
- [ ] **Verify market tracker frontend shows latest prices** — scrapers ran successfully 2026-03-30 (459 sealed + cards); confirm price data is visible on the admin/public frontend
- [ ] **Add "Run Price Scraper" on-demand button to admin panel** — trigger the `tcgplayer-price-scraper` Cloud Run job via GCP API or a new backend endpoint so prices can be refreshed without waiting for the schedule
- [ ] **Rename stale Cloud Scheduler jobs** — `tcgplayer-price-daily` → `tcgplayer-price-scraper-sealed-weekly`; `collection-showcase-daily-sync` → `collection-showcase-weekly-sync`; delete paused `sync-tcgplayer-prices-weekly` (was pointing at non-existent job)

### Market Tracker Admin — Sealed Products Page
- [ ] **Remove duplicate sync button on sealed products page** — there are currently two sync buttons that appear to do the same thing; investigate what each calls and consolidate to one
- [ ] **Add "Add by TCGPlayer ID/URL" button for sealed products** — enter a TCGPlayer product ID or product URL; backend resolves the product details (game, set, product type, packs per product, MSRP, release date) from the TCGPlayer API and inserts into `catalog.sealed_products`. This is different from the singles fetch-from-tcgplayer flow — sealed products are added one at a time, not by bulk-scraping a search page
- [ ] Extend pull rate import to One Piece, Hololive, Weiss Schwarz (no source JSON yet — need to source pull rates)

### Architecture — Unify Showcase Products with Catalog
- [x] **Unified products via composite string IDs** (2026-04-02) — added `name` + `image_url` columns to `catalog.sealed_products`; updated `inventory.catalog_products` VIEW to expose `product_subtype`, `pricecharting_url`, `image_url` (COALESCE from tcgplayer CDN); migrated the one transaction from UUID to `sealed:hololive:hl01:booster-display`; showcase syncer now reads from `catalog_products` (460+ products); `inventory.collection` VIEW joins prices via `catalog_products.tcgplayer_id` → `tcgplayer_price_history`; showcase products handler is now read-only; `inventory.products` table deprecated (still exists in BQ, unused).
- [x] **Renamed Displays → Shelves** throughout frontend UI (navbar, list page, view page, content titles); backend routes `/displays/...` unchanged

### Data & Catalog
- [ ] Verify GCS bucket `collection-showcase-data` has public read + data files uploaded (fallback path for GitHub)
- [ ] Data sync job (`collection-showcase-data-sync` Cloud Run job) — exists in GCP but not yet wired; currently data is synced manually by running the Python sync script
- [ ] Collection page — review if data is displaying correctly now that prices are live
- [ ] Price history page — `market_data.price_history` table is still empty; the showcase syncer exports it but the showcase collection view now reads from `market_data.tcgplayer_price_history` directly. Decide if price_history.json on the showcase site should show tcgplayer price history instead.
- [ ] Single cards — Hololive single cards not yet in `catalog.single_cards`; needed before binder card picker works for Hololive
- [ ] Single cards — MTG singles not yet tracked (deferred; focus is sealed products first)
- [ ] Single cards — Weiss Schwarz singles not yet tracked

## Done
- [x] Added "Fill from Set" bulk binder populate (2026-03-29) — admin button on binder view; picks game + set + optional rarity filter, auto-fills pages in card-number order (front side then back side per page), appends after any existing pages
- [x] Renamed Displays → Shelves in frontend UI (2026-03-29) — navbar, list/view pages, content titles; backend `/displays/...` routes unchanged
- [x] Bulk-inserted Pokemon pull rates into `catalog.set_pull_rates` (2026-03-28):
  - 258 rows across all Pokemon eras (Base Set → Scarlet & Violet)
  - Hard rarities only: holo_rare, double_rare, ultra_rare, illustration_rare, special_illustration_rare, hyper_rare, ace_spec_rare, shiny_rare, shiny_ultra_rare, black_white_rare, secret_rare, amazing_rare, radiant_rare, full_art, trainer_gallery_*
  - Source: `FutureGadgetResearch/set-value-tracking-backend` pull rates JSON
  - Script: `collection-market-tracker-backend/scripts/catalog/bulk_insert_pokemon_pull_rates.py`
  - MDS (master_difficulty_score) stored from source JSON; p50/p75/p90 computed client-side in UI from pull_rate_per_pack + unique_card_count
- [x] Redesigned admin set-pull-rates UI to show p50/p75/p90 percentile packs-to-complete (Gumbel quantile formula) instead of single MDS mean value (2026-03-28)
- [x] Redeployed showcase backend to Cloud Run (2026-03-29) — revision collection-showcase-00044-mxc; all 16 binder/display routes live at https://collection-showcase-957536135168.us-central1.run.app
- [x] Bulk-inserted sealed products for MTG, Hololive, and Weiss Schwarz (2026-03-28):
  - MTG: 16 sets × 2-3 product types = 40 rows (neo→tdm; draft/set/play booster boxes + collector boxes)
  - Hololive: 5 new sets (hl02 Blooming Radiance through hl06 Ayakashi Vermilion) + hl02 2nd print = 6 rows
  - Weiss Schwarz: 22 English booster boxes + 11 English premium booster boxes = 33 rows
  - Synced sealed-products.json (460 total) + single-cards.json (22,919) → GCS + GitHub
  - Script: `collection-market-tracker-backend/scripts/catalog/bulk_insert_sealed_products.py`
- [x] Bulk-imported catalog data (2026-03-28):
  - Pokemon sealed products: 335 products across all eras (Base Set → Scarlet & Violet)
  - One Piece sealed products: 38 products across op01–op09 (more sets TBD as they release)
  - Pokemon singles: 18,936 cards across 122 English sets (Base Set 1999 → current SV/Black Bolt)
  - One Piece singles: 3,242 cards across 19 sets (op01–op14, eb01–eb03, prb01–prb02)
  - Synced sealed-products.json (381 total) + single-cards.json (22,919 total) to GCS + GitHub
  - Memory rule saved: always sync after direct BQ inserts
  - Scripts in `collection-market-tracker-backend/scripts/catalog/`: `bulk_fetch_pokemon_singles.py`, `bulk_fetch_onepiece_singles.py`
  - Added `POST /single-cards/fetch-from-tcgplayer` backend endpoint + admin UI "Fetch from TCGPlayer" button
- [x] Built binder/display showcase feature (full-stack):
  - 4 new BQ tables: `inventory.binders`, `inventory.binder_slots`, `inventory.showcase_displays`, `inventory.showcase_display_items`
  - Backend: `binders.go` + `displays.go` handlers (16 new API routes in `main.go`)
  - Backend: `syncer.go` updated with `SyncBinders()` + `SyncDisplays()` — outputs `binders/index.json`, `binders/{id}.json`, `displays/index.json`, `displays/{id}.json`
  - Frontend: binder list page, binder viewer (3×3 grid, front/back panels, CSS slide transition, admin card picker)
  - Frontend: display list page, display viewer (bookshelf rows + bin grid modes, admin product picker)
  - Navbar updated with Binders + Displays links
  - Data repo stubs committed and pushed
- [x] Fixed unrealized P&L pipeline:
  - Added Hololive Booster Box (hl01) to `catalog.sealed_products` so scraper tracks it
  - Ran `tcgplayer-price-scraper` — current market price $52.95 now in `market_data.tcgplayer_price_history`
  - Updated `inventory.collection` view to bridge `tcgplayer_price_history` → showcase product UUIDs via `inventory.products.tcgplayer_id` (bypasses empty `market_data.price_history` table)
  - Unrealized P&L now live: -$36.60 on 12 boxes bought at $56, now worth $52.95
- [x] Populated BQ: Hololive Booster Box product + 12-box buy transaction @ $56 (Feb 2026)
- [x] Confirmed BQ state: `inventory.products`, `inventory.transactions`, `inventory.collection` all empty as of 2026-03-27; now populated
- [x] Fixed products page: was gated behind Firebase auth, now loads publicly; admin controls (sync/add/edit/delete) still require sign-in
- [x] Fixed transactions data: `price` → `unit_price` field rename to match backend schema
- [x] `collection-showcase-data` GitHub repo confirmed public
- [x] All fixes committed and pushed
