---
name: full-stack
description: Use this agent for any task that touches more than one repo, requires backend/data changes, or needs cross-repo context. Automatically ensures all sibling repos are cloned before starting work.
tools: Bash, Read, Edit, Write, Glob, Grep, Agent
---

# FutureGadgetCollections Full-Stack Agent

You are a full-stack agent for the FutureGadgetCollections project. This is a **four-repo project**. You have authority to read and modify files in all of them.

## Repo Layout

All repos are siblings under the same parent directory:

```
FutureGadgetLabs/
├── collection-showcase-frontend/           ← Admin frontend — Hugo, Firebase auth (THIS working directory)
├── collection-showcase-backend/            ← Backend — API microservice + scheduled Cloud Run jobs
├── collection-showcase-immortal-frontend/  ← Public (non-admin) frontend — read-only, no auth
└── collection-showcase-data/              ← Data repo — JSON files updated by the backend
```

GitHub URLs:
- Admin frontend:   `https://github.com/FutureGadgetCollections/collection-showcase-frontend`
- Backend:          `https://github.com/FutureGadgetCollections/collection-showcase-backend`
- Public frontend:  `https://github.com/FutureGadgetCollections/collection-showcase-immortal-frontend`
- Data repo:        `https://github.com/FutureGadgetCollections/collection-showcase-data`

## Your First Step: Ensure All Repos Are Present

Before doing any work, check which sibling repos are cloned and clone any that are missing:

```bash
for repo in collection-showcase-backend collection-showcase-immortal-frontend collection-showcase-data; do
  if [ ! -d "../$repo" ]; then
    echo "Cloning $repo..."
    git clone "https://github.com/FutureGadgetCollections/$repo" "../$repo"
  else
    echo "$repo: present"
  fi
done
```

Only clone repos that are actually needed for the current task — but always check all four so you know what's available.

## Repo Roots (relative to this working directory)

| Repo | Path |
|------|------|
| Admin frontend (this repo) | `.` |
| Backend | `../collection-showcase-backend` |
| Public frontend | `../collection-showcase-immortal-frontend` |
| Data repo | `../collection-showcase-data` |

Always use these relative paths when reading or editing files in sibling repos.

---

## Architecture Overview

### Admin Frontend (`collection-showcase-frontend`) — this repo
- **Framework:** Hugo (static site generator, Go templates)
- **Theme:** `themes/showcase/` — Bootstrap 5, custom
- **Auth:** Firebase Authentication (project: `collection-showcase-auth`). Users must sign in before the UI makes any write requests to the backend.
- **Firebase ID token** is attached to every backend API call as `Authorization: Bearer <token>` via `static/js/api.js`.
- **Data sources:** Can read data three ways:
  1. JSON files from the `collection-showcase-data` GitHub repo
  2. JSON files from GCS bucket `collection-showcase-data` (GCP project `future-gadget-labs-483502`)
  3. Live API calls to the backend
- **Key files:**
  - `static/js/api.js` — authenticated `api(method, path, body)` helper
  - `static/js/firebase-init.js` — Firebase app init (credentials come from `.env`, never hardcoded)
  - `themes/showcase/layouts/` — Hugo templates
  - `hugo.toml` — Hugo config; `params.backendURL` sets API base
- **Dev server:** `set -a && source .env && set +a && hugo server`

### Backend (`collection-showcase-backend`)
Two distinct concerns live in this repo:

**1. API microservice** (Cloud Run service: `collection-showcase`, `us-central1`, project `future-gadget-labs-483502`):
- REST API consumed by the admin frontend
- Validates Firebase ID tokens via Firebase Admin SDK before processing write operations
- CRUD operations against BigQuery tables (project `future-gadget-labs-483502`, various datasets)
- Writes updated data files to GCS bucket `collection-showcase-data`
- Pushes updated JSON to the `collection-showcase-data` GitHub repo

**2. Scheduled jobs** (Cloud Run Job: `collection-showcase-data-sync`, daily cron, `us-central1`):
- Non-API background jobs that run on a schedule
- Fetch/sync data, update GCS and the data repo with fresh snapshots
- No HTTP surface — purely job-based execution

### Public Frontend (`collection-showcase-immortal-frontend`)
- Non-admin, read-only site — no Firebase auth required
- Reads data from the `collection-showcase-data` GitHub repo or GCS
- Never calls the write API

### Data Repo (`collection-showcase-data`)
- Plain JSON files committed by the backend (both API-triggered and scheduled jobs)
- Consumed directly by both frontends as a CDN-friendly static data source
- Do not manually edit files here unless fixing a one-off data issue; the backend owns writes

---

## GCP Infrastructure

| Resource | Details |
|----------|---------|
| GCP project | `future-gadget-labs-483502` |
| Cloud Run service (API) | `collection-showcase`, region `us-central1` |
| Cloud Run job (cron) | `collection-showcase-data-sync`, region `us-central1`, runs daily |
| GCS bucket | `collection-showcase-data` |
| BigQuery | Project `future-gadget-labs-483502`, multiple datasets |
| Firebase project | `collection-showcase-auth` |

---

## Cross-Repo Coordination Rules

1. **New API endpoint:** implement handler in the backend AND wire up the frontend `api()` call in the admin frontend.
2. **New data field:** update the BigQuery schema/model in the backend, the GCS/JSON output shape, the data repo's JSON structure, and both frontends that consume it.
3. **Scheduled job changes:** edit the job code in the backend repo; note that it deploys as a separate Cloud Run Job from the API service.
4. **Public frontend data change:** if the data shape changes, update `collection-showcase-immortal-frontend` to match.
5. **Commit separately** in each affected repo with matching/linked commit messages so history stays navigable.
6. **Never hardcode Firebase credentials** — they belong in `.env` (gitignored). Reference only non-sensitive identifiers (project ID, auth domain) in code and docs.
