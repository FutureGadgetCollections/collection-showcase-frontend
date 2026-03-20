# collection-showcase-frontend

## Project Overview

This is the **frontend** of the FutureGadgetCollections application — a Hugo-based site that provides a UI for browsing and managing a collection showcase.

## Related Repositories

| Repo | Role |
|------|------|
| **This repo** (`collection-showcase-frontend`) | Hugo frontend, Firebase-authenticated UI |
| [`collection-showcase-backend`](https://github.com/FutureGadgetCollections/collection-showcase-backend) | REST/API backend that this frontend calls |

## Architecture

- **Framework:** [Hugo](https://gohugo.io/) — static site generator with Go templates
- **Theme:** Custom theme (`themes/showcase/`) — minimal Bootstrap 5 layout, no external theme dependency
- **Auth:** Firebase Authentication — users must be authenticated via Firebase before any requests are made to the backend. The Firebase ID token is attached to backend API calls so the backend can verify identity server-side.
- **Backend communication:** All data mutations (create, update, delete) are gated behind a valid Firebase session. The `api()` helper in `static/js/api.js` handles token attachment automatically.

## Key Files

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

1. User lands on the site and is prompted to sign in via Firebase Auth (Google, email/password, etc.)
2. On successful sign-in, Firebase issues an ID token.
3. The frontend attaches the ID token as a Bearer token (`Authorization: Bearer <token>`) on all requests to the backend.
4. The backend validates the token via the Firebase Admin SDK before processing any write operations.

## Development Notes

- Hugo config lives in `hugo.toml` (or `config.toml` / `config/`)
- Firebase config (API key, project ID, etc.) goes in `.env` — never commit this file (already in `.gitignore`)
- Keep Firebase credentials in environment variables; reference them in Hugo via a JS bundle or a separate config file excluded from git
- The `.gitignore` is Go-flavored by origin — update it as needed for Hugo artifacts (e.g., `public/`, `resources/_gen/`)
