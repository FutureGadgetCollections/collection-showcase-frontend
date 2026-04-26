# collection-showcase-frontend

## Project Overview

Public-facing read-only showcase site for the **Collection Market Tracker** — a Hugo-based static site that displays TCG collection and pricing data. No authentication, no write operations; data is fetched from the data repo and GCS bucket published by the backend.

## Multi-Repo Setup

All repos are siblings under the same parent directory. Run `setup.sh` from `collection-admin` to clone any missing sibling repos.

## All Repositories

### Showcase system (this site's data pipeline)

| Repo | GitHub | Local Path | Purpose |
|------|--------|-----------|---------|
| Showcase frontend (this repo) | `FutureGadgetCollections/collection-showcase-frontend` | `../collection-showcase-frontend` | Public Hugo site — read-only, no auth |
| Showcase backend | `FutureGadgetCollections/collection-showcase-backend` | `../collection-showcase-backend` | Go API (Cloud Run) — CRUD for products/transactions; data-sync job writes GCS + GitHub |
| Showcase data | `FutureGadgetCollections/collection-showcase-data` | `../collection-showcase-data` | Static JSON (products, transactions, collection, price_history) — written by sync job, read by this site |

### Market tracker system (shared BQ project)

| Repo | GitHub | Local Path | Purpose |
|------|--------|-----------|---------|
| Market tracker frontend admin | `FutureGadgetCollections/collection-admin` | `../collection-admin` | Hugo admin UI — manages catalog products; CRUD via market-tracker backend API |
| Market tracker backend | `FutureGadgetCollections/collection-market-tracker-backend` | `../collection-market-tracker-backend` | Go API + TCGPlayer price scraper (Cloud Run jobs) — writes `catalog.*`, `market_data.tcgplayer_price_history`, `inventory.transactions` |
| Market tracker data | `FutureGadgetCollections/collection-market-tracker-data` | `../collection-market-tracker-data` | Static JSON published by market-tracker backend |

## GCP Infrastructure

| Resource | Details |
|----------|---------|
| GCP Project | `future-gadget-labs-483502` |
| Cloud Run service (API) | `collection-market-tracker` — `us-central1` |
| Cloud Run job (price scraper) | `tcgplayer-price-scraper` — `us-central1` — daily at 08:00 UTC via Cloud Scheduler |
| Cloud Run job (data sync) | `collection-showcase-data-sync` — `us-central1` (planned, not yet configured) |
| GCS bucket | `collection-tracker-data` |
| BigQuery | Project `future-gadget-labs-483502` — datasets: `catalog`, `market_data` |
| Firebase project | `collection-showcase-auth` (used by admin frontend only; this site has no auth) |

## Architecture

- **Framework:** [Hugo](https://gohugo.io/) — static site generator with Go templates
- **Theme:** Custom theme (`themes/showcase/`) — Bootstrap 5 layout
- **Auth:** None — public read-only site
- **Data reads:** Static JSON from GitHub Raw (`collection-market-tracker-data`) with GCS fallback (`collection-tracker-data` bucket)
- **Data source:** `hugo.toml` params (`params.gcs.data.bucket`, etc.) configure the bucket and GitHub repo

## Data Flow

```
BigQuery (source of truth)
  └── Backend API / daily cron
        ├──► gs://collection-tracker-data/data/<resource>.json  (GCS)
        └──► data/<resource>.json  (collection-market-tracker-data GitHub repo)

This site reads: GitHub Raw first ► GCS fallback
```

## Key Files

| Path | Purpose |
|------|---------|
| `hugo.toml` | Hugo config — params include GCS bucket, GitHub data repo |
| `themes/showcase/layouts/` | Hugo templates |
| `themes/showcase/layouts/partials/` | head, navbar, footer, scripts partials |
| `static/js/data-loader.js` | `loadJsonData(filename)` — GitHub-first, GCS-fallback data fetching |
| `static/css/app.css` | Style overrides on top of Bootstrap 5 |

## Development Notes

- This site is read-only — no Firebase auth, no write API calls
- Hugo config lives in `hugo.toml`; no `.env` file needed for local dev (no secrets required)
- GCS bucket and GitHub data repo are set in `hugo.toml` params (non-sensitive, safe to commit)
- Design reference for the admin frontend — both sites read the same data files