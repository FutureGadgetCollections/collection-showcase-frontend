# Collection Showcase — TODO

## Up Next
- [ ] Test binder/display UI — create first binder + display via admin (backend is now live with routes)
- [ ] Validate pull rate calculator — confirm p50/p75/p90 and all 3 calc tabs render correctly for Pokemon SV sets in admin; check ace_spec_rare rows (mds=null, may be missing unique_card_count) show graceful — fallback
- [ ] Build set difficulty dashboard — `catalog.set_pull_rates` now has 258 Pokemon rows + 16 Lorcana rows; showcase p50/p75/p90 packs-to-complete across sets and eras

## Backlog

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
