# Collection Showcase — TODO

## In Progress
- [ ] Add transactions to `collection-showcase-data` — user wants to log their collection purchases

## Up Next
- [ ] Verify `collection-showcase-data` GitHub repo is **public** (required for GitHub-raw data loading to work for anonymous visitors)
- [ ] Verify GCS bucket `collection-showcase-data` has public read + data files uploaded (fallback path)
- [ ] Commit + push fixes from this session (see Done section)

## Backlog
- [ ] Data sync job (`collection-showcase-data-sync` Cloud Run job) — not yet configured in GCP; currently data files are updated manually
- [ ] Collection page — review if data is loading correctly (same GitHub/GCS concerns as transactions/products)
- [ ] Price history page — same review needed

## Done
- [x] Fixed products page: was gated behind Firebase auth, now loads publicly; admin controls (sync/add/edit/delete) still require sign-in
- [x] Fixed transactions data: `transactions.json` had `price` field, renamed to `unit_price` to match backend schema and frontend template
- [x] `collection-showcase-data` repo is cloned and synced with remote
