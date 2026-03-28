# Collection Showcase — TODO

## In Progress
- [ ] Add more products and transactions as needed

## Up Next
- [ ] **Redeploy showcase backend to Cloud Run** — new binder/display routes (16 endpoints) need to be live
  - `cd ../collection-showcase-backend && gcloud run deploy collection-showcase --source . --region us-central1`
- [ ] Test binder/display UI after backend deploy — create first binder + display via admin

## Backlog
- [ ] Verify GCS bucket `collection-showcase-data` has public read + data files uploaded (fallback path for GitHub)
- [ ] Data sync job (`collection-showcase-data-sync` Cloud Run job) — exists in GCP but not yet wired; currently data is synced manually by running the Python sync script
- [ ] Collection page — review if data is displaying correctly now that prices are live
- [ ] Price history page — `market_data.price_history` table is still empty; the showcase syncer exports it but the showcase collection view now reads from `market_data.tcgplayer_price_history` directly. Decide if price_history.json on the showcase site should show tcgplayer price history instead.
- [ ] Single cards — Hololive single cards not yet in `catalog.single_cards`; needed before binder card picker works for Hololive

## Done
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
