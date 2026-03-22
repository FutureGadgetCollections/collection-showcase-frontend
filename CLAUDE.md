# collection-showcase-frontend

## Project Overview

This is the **admin frontend** of the FutureGadgetCollections application — a Hugo-based site that lets authorized users browse and manage the collection via a Firebase-authenticated UI.

## Repository Structure

This is a **four-repo project**. All repos should be cloned as siblings under the same parent directory:

```
FutureGadgetLabs/
├── collection-showcase-frontend/           ← Admin frontend — Hugo, Firebase auth (this repo)
├── collection-showcase-backend/            ← Backend — REST API + scheduled Cloud Run jobs
├── collection-showcase-immortal-frontend/  ← Public (non-admin) frontend — read-only, no auth
└── collection-showcase-data/              ← Data repo — JSON files auto-updated by the backend
```

| Repo | GitHub URL | Role |
|------|-----------|------|
| `collection-showcase-frontend` | https://github.com/FutureGadgetCollections/collection-showcase-frontend | Admin frontend (this repo) |
| `collection-showcase-backend` | https://github.com/FutureGadgetCollections/collection-showcase-backend | REST API microservice + scheduled jobs |
| `collection-showcase-immortal-frontend` | https://github.com/FutureGadgetCollections/collection-showcase-immortal-frontend | Public frontend |
| `collection-showcase-data` | https://github.com/FutureGadgetCollections/collection-showcase-data | Static JSON data files |

## Architecture

### This Repo — Admin Frontend
- **Framework:** [Hugo](https://gohugo.io/) — static site generator with Go templates
- **Theme:** Custom theme (`themes/showcase/`) — minimal Bootstrap 5 layout
- **Auth:** Firebase Authentication (project: `collection-showcase-auth`). Users must sign in before the UI sends any write requests.
- **Data sources:** The admin frontend can read data three ways:
  1. JSON files from the `collection-showcase-data` GitHub repo
  2. JSON files from GCS bucket `collection-showcase-data` (GCP project `future-gadget-labs-483502`)
  3. Live API calls to the backend
- **Backend communication:** All write requests include a Firebase ID token as `Authorization: Bearer <token>`. The `api()` helper in `static/js/api.js` handles token attachment automatically.

### Backend (`collection-showcase-backend`)
Two concerns in one repo:
1. **API microservice** — REST API consumed by the admin frontend; validates Firebase tokens; reads/writes BigQuery; updates GCS and the data repo
2. **Scheduled jobs** — Cloud Run Jobs (no HTTP surface) that run on a schedule to sync/update data

### Public Frontend (`collection-showcase-immortal-frontend`)
- Read-only, no Firebase auth
- Reads from the data repo or GCS only — never calls the write API

### Data Repo (`collection-showcase-data`)
- Plain JSON files committed by the backend (API-triggered or scheduled)
- Do not manually edit; the backend owns writes here

## GCP Infrastructure

| Resource | Details |
|----------|---------|
| GCP project | `future-gadget-labs-483502` |
| Cloud Run service (API) | `collection-showcase`, region `us-central1` |
| Cloud Run job (daily cron) | `collection-showcase-data-sync`, region `us-central1` |
| GCS bucket | `collection-showcase-data` |
| BigQuery | Project `future-gadget-labs-483502`, multiple datasets |
| Firebase project | `collection-showcase-auth` |

## Key Files (This Repo)

| Path | Purpose |
|------|---------|
| `themes/showcase/layouts/` | Hugo templates (baseof, list, index) |
| `themes/showcase/layouts/partials/` | head, navbar, footer, scripts partials |
| `static/js/firebase-init.js` | Firebase app init + global `authSignOut()` |
| `static/js/api.js` | Authenticated `api(method, path, body)` helper |
| `static/js/app.js` | Global `showToast()` utility |
| `static/css/app.css` | Minimal style overrides on top of Bootstrap 5 |
| `content/collections/_index.md` | Collections list page |
| `.env.example` | Template for Firebase + backend env vars |
| `hugo.toml` | Hugo config — `params.backendURL` sets the API base |

## Auth Flow

1. User lands on the site and signs in via Firebase Auth (Google, email/password, etc.)
2. Firebase issues an ID token.
3. The frontend attaches the token as `Authorization: Bearer <token>` on all backend requests.
4. The backend validates the token via the Firebase Admin SDK before processing write operations.

**Never hardcode Firebase credentials** — they belong in `.env` (gitignored). Reference only non-sensitive identifiers (project ID, auth domain) in code and docs.

## Development Notes

- Hugo config lives in `hugo.toml`
- Firebase config goes in `.env` — never commit this file (already in `.gitignore`)
- The `.gitignore` is Go-flavored by origin — update it as needed for Hugo artifacts (e.g., `public/`, `resources/_gen/`)

## Running the Dev Server

**Always** source `.env` first — Hugo does not auto-read `.env` files:

```bash
set -a && source .env && set +a && hugo server
```

## Custom Agents

A `full-stack` sub-agent is defined in `.claude/agents/full-stack.md`. It:
- Checks all four sibling repos and clones any that are missing
- Has full context on every repo's role, data flow, and GCP infrastructure
- Handles tasks that span multiple repos simultaneously

Claude Code will invoke it automatically for cross-repo tasks, or you can ask for it explicitly.
