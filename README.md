# collection-showcase-frontend

Admin UI for the FutureGadgetCollections showcase — a Hugo-based static site for browsing and managing a TCG collection.

## Purpose

This frontend is a lightweight admin interface for performing CRUD operations against the collection database. It is not intended as a public-facing storefront — it is designed for a small whitelist of administrators to manage products, transactions, and price history.

## Architecture

```
Browser
  │
  ├── Read (products, transactions, price history, collection)
  │     └── GitHub Raw (FutureGadgetCollections/collection-showcase-data)
  │           └── GCS fallback (collection-showcase-data bucket)
  │
  └── Write (create, update, delete)
        └── Backend API (collection-showcase-backend)
              ├── Firebase Auth token verified against collection-showcase-auth
              ├── Operation applied to BigQuery
              └── Updated JSON published to GitHub + GCS
```

### Data Flow

**Reads** are served from static JSON files published by the backend after each mutation. The frontend fetches from GitHub first and falls back to GCS if unavailable:

- GitHub: `https://raw.githubusercontent.com/FutureGadgetCollections/collection-showcase-data/main/<file>.json`
- GCS fallback: `https://storage.googleapis.com/collection-showcase-data/<file>.json`

**Writes** (create, update, delete) go directly to the backend API, which handles the database operation and then republishes the static data files to both GitHub and GCS.

## Authentication

Authentication is handled by [Firebase Auth](https://console.firebase.google.com/project/collection-showcase-auth/) (project: `collection-showcase-auth`). Users sign in with Google and receive a Firebase ID token, which is attached as a Bearer token on all write requests to the backend.

Access is further restricted to a whitelist of allowed emails configured via the `ALLOWED_EMAILS` environment variable — both on the frontend (UI gating) and enforced server-side on the backend.

## Related Repositories

| Repo | Role |
|------|------|
| **This repo** | Hugo frontend admin UI |
| [`collection-showcase-backend`](https://github.com/FutureGadgetCollections/collection-showcase-backend) | REST API — handles auth, BigQuery mutations, and data publishing |
| [`collection-showcase-data`](https://github.com/FutureGadgetCollections/collection-showcase-data) | Published static JSON files read by this frontend |

## Tech Stack

- **[Hugo](https://gohugo.io/)** — static site generator
- **Bootstrap 5** — UI framework
- **Firebase Auth (JS SDK)** — Google sign-in and ID token issuance
- **GitHub Raw / GCS** — static data sources for reads

## Local Development

1. Copy `.env.example` to `.env` and fill in your Firebase config and backend URL.
2. Start the dev server:

```bash
source .env && \
  HUGO_PARAMS_FIREBASE_API_KEY=$HUGO_PARAMS_FIREBASE_API_KEY \
  HUGO_PARAMS_FIREBASE_AUTH_DOMAIN=$HUGO_PARAMS_FIREBASE_AUTH_DOMAIN \
  HUGO_PARAMS_FIREBASE_PROJECT_ID=$HUGO_PARAMS_FIREBASE_PROJECT_ID \
  HUGO_PARAMS_FIREBASE_STORAGE_BUCKET=$HUGO_PARAMS_FIREBASE_STORAGE_BUCKET \
  HUGO_PARAMS_FIREBASE_MESSAGING_SENDER_ID=$HUGO_PARAMS_FIREBASE_MESSAGING_SENDER_ID \
  HUGO_PARAMS_FIREBASE_APP_ID=$HUGO_PARAMS_FIREBASE_APP_ID \
  HUGO_PARAMS_BACKENDURL=$HUGO_PARAMS_BACKENDURL \
  HUGO_PARAMS_ALLOWED_EMAILS=$HUGO_PARAMS_ALLOWED_EMAILS \
  hugo server --port 1313
```

3. Open [http://localhost:1313](http://localhost:1313) and sign in with an allowed email.

## Configuration

All configuration is supplied via `HUGO_PARAMS_*` environment variables at build/serve time. See `.env.example` for the full list.

| Variable | Purpose |
|----------|---------|
| `HUGO_PARAMS_FIREBASE_*` | Firebase project config |
| `HUGO_PARAMS_BACKENDURL` | Backend API base URL |
| `HUGO_PARAMS_ALLOWED_EMAILS` | Comma-separated list of admin emails |
| `HUGO_PARAMS_GCS_DATA_BUCKET` | GCS bucket name for static data fallback |
| `HUGO_PARAMS_GITHUB_DATA_REPO` | GitHub repo for static data (e.g. `org/repo`) |
