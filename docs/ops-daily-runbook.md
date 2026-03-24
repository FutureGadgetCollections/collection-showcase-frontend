# Daily Ops Runbook

Daily health checks across all FutureGadgetLabs / FG-PolyLabs systems.

---

## Systems Overview

| System | GCP Project | Purpose |
|--------|-------------|---------|
| Collection Showcase | `future-gadget-labs-483502` | TCG collection + price tracking |
| Weather / Cloud Predict | `fg-polylabs` | Weather prediction market tracking |
| Doomsday Predict | `fg-polylabs` | Geopolitical prediction market tracking |

---

## Check 1: Daily Data Sync (`collection-showcase-data-sync`)

**Purpose:** Exports BigQuery inventory + price data to GCS and GitHub so the public frontend can read it.

**Schedule:** Daily ~03:00 UTC via Cloud Scheduler (`future-gadget-labs-483502`)

### BigQuery tables read

| Project | Dataset | Table / View | Notes |
|---------|---------|--------------|-------|
| `future-gadget-labs-483502` | `inventory` | `products` | All tracked products |
| `future-gadget-labs-483502` | `inventory` | `transactions` | Buy/sell history |
| `future-gadget-labs-483502` | `inventory` | `collection` | **View** — current holdings (qty > 0) |
| `future-gadget-labs-483502` | `market_data` | `price_history` | Price snapshots from TCGPlayer |

### Expected files on GCS (`gs://collection-showcase-data/`)

| File | Expected size | Notes |
|------|--------------|-------|
| `collection.json` | > 100 bytes | Non-empty if holdings exist |
| `transactions.json` | > 100 bytes | Non-empty if transactions exist |
| `products.json` | > 100 bytes | Non-empty if products exist |
| `price_history.json` | > 100 bytes | Non-empty after first price sync |

### Expected files on GitHub (`FutureGadgetCollections/collection-showcase-data`)

Same 4 files as above. Each successful run creates a commit: `chore: sync data <timestamp>`.

### Verification commands

```bash
# 1. Check job execution status (X = failed, + = success)
gcloud run jobs executions list \
  --job=collection-showcase-data-sync \
  --region=us-central1 \
  --project=future-gadget-labs-483502 \
  --limit=5

# 2. Check logs for errors on the latest execution
gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.job_name=collection-showcase-data-sync" \
  --project=future-gadget-labs-483502 \
  --freshness=2h --limit=30 \
  --format="table(timestamp,textPayload)"

# 3. Check GCS file timestamps (all should be today)
gcloud storage ls -l gs://collection-showcase-data/

# 4. Check GitHub for today's sync commit
cd ../collection-showcase-data && git pull && git log --oneline --since="24 hours ago"
```

### Success criteria

- [ ] Latest execution row shows `+` (complete) and `1 / 1`
- [ ] No `exit(1)` or `Error` lines in logs
- [ ] All 4 GCS files have today's date
- [ ] All 4 GCS files are > 100 bytes
- [ ] At least one `chore: sync data` commit in the data repo today

### Common failures

| Error | Likely cause | Fix |
|-------|-------------|-----|
| `Unrecognized name: <column>` | BQ schema out of sync with query | Update the query in `collection-showcase-backend/internal/datasync/` to match current BQ schema |
| `0 / 1` on execution | Container crashed before writing | Check logs for panic or startup error |
| Files updated but all 2 bytes (`[]`) | Query succeeded but returned no rows | Check that BQ tables have data; check BQ permissions |

---

## Check 2: Weather Sync (`weather-sync`)

**Purpose:** Exports weather prediction market snapshots from BigQuery to GCS and GitHub.

**Schedule:** Daily ~03:00 UTC via Cloud Scheduler (`fg-polylabs`)

### BigQuery tables read

| Project | Dataset | Table | Notes |
|---------|---------|-------|-------|
| `fg-polylabs` | `weather` | `polymarket_snapshots` | Daily Polymarket price snapshots |
| `fg-polylabs` | `weather` | `tracked_cities` | Reference list of tracked cities |

### Expected files on GCS (`gs://fg-polylabs-weather-data/`)

| File | Notes |
|------|-------|
| `data/*.jsonl` | One or more JSONL exports per table |

### Expected files on GitHub (`FG-PolyLabs/cloud-predict-analytics-data`)

Same files as GCS.

### Verification commands

```bash
# 1. Check execution status
gcloud run jobs executions list \
  --job=weather-sync \
  --region=us-central1 \
  --limit=5

# 2. Check logs
gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.job_name=weather-sync" \
  --freshness=2h --limit=30 \
  --format="table(timestamp,textPayload)"

# 3. Check GCS file timestamps
gcloud storage ls -l gs://fg-polylabs-weather-data/data/

# 4. Spot-check BQ for yesterday's data
# Run in BigQuery console:
# SELECT date, COUNT(*) AS rows
# FROM `fg-polylabs.weather.polymarket_snapshots`
# WHERE date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
# GROUP BY date
```

### Success criteria

- [ ] Latest execution shows `+` and `1 / 1`
- [ ] No errors in logs
- [ ] GCS data files have today's timestamp
- [ ] BQ query returns rows > 0 for yesterday

---

## Check 3: Daily Data Fetch Jobs

Two jobs fetch data from external sources into BigQuery. Both should run before the sync jobs above.

### 3a. TCGPlayer Price Sync (`tcgplayer-price-sync`)

**Purpose:** Scrapes TCGPlayer prices and merges them into `market_data.price_history`.

**Schedule:** Daily ~01:00–02:00 UTC (`future-gadget-labs-483502`)

#### BigQuery tables written

| Project | Dataset | Table | Write pattern |
|---------|---------|-------|--------------|
| `future-gadget-labs-483502` | `market_data` | `price_history` | INSERT — one row per product per day |

#### Verification commands

```bash
# 1. Check execution status
gcloud run jobs executions list \
  --job=tcgplayer-price-sync \
  --region=us-central1 \
  --project=future-gadget-labs-483502 \
  --limit=5

# 2. Check logs
gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.job_name=tcgplayer-price-sync" \
  --project=future-gadget-labs-483502 \
  --freshness=4h --limit=30 \
  --format="table(timestamp,textPayload)"

# 3. Verify BQ data for yesterday (run in BigQuery console):
# SELECT snapshot_date, COUNT(*) AS rows
# FROM `future-gadget-labs-483502.market_data.price_history`
# WHERE snapshot_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
# GROUP BY snapshot_date
```

#### Success criteria

- [ ] Latest execution shows `+` and `1 / 1`
- [ ] No errors in logs
- [ ] BQ query returns rows > 0 for yesterday's date

---

### 3b. Doomsday Polymarket Fetch (`doomsday-polymarket`)

**Purpose:** Fetches Polymarket prediction market snapshots and merges them into `doomsday.market_snapshots`.

**Schedule:** Daily ~01:00 UTC (`fg-polylabs`)

#### BigQuery tables written

| Project | Dataset | Table | Write pattern |
|---------|---------|-------|--------------|
| `fg-polylabs` | `doomsday` | `market_snapshots` | MERGE on (market_id, date) |
| `fg-polylabs` | `doomsday` | `markets` | Reference — updated on config changes only |

#### Verification commands

```bash
# 1. Check execution status
gcloud run jobs executions list \
  --job=doomsday-polymarket \
  --region=us-central1 \
  --limit=5

# 2. Check logs
gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.job_name=doomsday-polymarket" \
  --freshness=4h --limit=30 \
  --format="table(timestamp,textPayload)"

# 3. Verify BQ data for yesterday (run in BigQuery console):
# SELECT date, COUNT(*) AS rows
# FROM `fg-polylabs.doomsday.market_snapshots`
# WHERE date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
# GROUP BY date
```

#### Success criteria

- [ ] Latest execution shows `+` and `1 / 1`
- [ ] No errors in logs
- [ ] BQ query returns rows > 0 for yesterday's date

---

### 3c. Doomsday Exporter (`doomsday-exporter`)

**Purpose:** Exports doomsday market data from BigQuery to GCS and per-event JSON files.

**Schedule:** Daily ~03:30 UTC, after `doomsday-polymarket` completes (`fg-polylabs`)

#### Expected files on GCS (`gs://fg-polylabs-doomsday/`)

| Path | Notes |
|------|-------|
| `index.json` | Market index — updated every run |
| `data/markets.jsonl` | Full market config list — updated when markets change |
| `events/{slug}.json` | One file per active market — updated every run |

#### Verification commands

```bash
# 1. Check execution status
gcloud run jobs executions list \
  --job=doomsday-exporter \
  --region=us-central1 \
  --limit=5

# 2. Check GCS timestamps (index.json and recent event files should be today)
gcloud storage ls -l gs://fg-polylabs-doomsday/
gcloud storage ls -l gs://fg-polylabs-doomsday/events/
```

#### Success criteria

- [ ] Latest execution shows `+` and `1 / 1`
- [ ] `index.json` has today's timestamp
- [ ] At least some `events/*.json` files have today's timestamp

---

## Check 4: Service Health

Run after all jobs to confirm the APIs are serving correctly.

### collection-showcase (future-gadget-labs-483502)

```bash
curl https://collection-showcase-957536135168.us-central1.run.app/health
# Expected: {"status":"ok"}

curl https://collection-showcase-957536135168.us-central1.run.app/info
# Expected: {"version":"...","env":{...}}

# Spot-check a public data endpoint
curl https://collection-showcase-957536135168.us-central1.run.app/collection | head -c 200
```

### weather-api (fg-polylabs)

```bash
curl https://weather-api-846376753241.us-central1.run.app/health
# Expected: {"status":"ok"}
```

### doomsday-api (fg-polylabs)

```bash
curl https://doomsday-api-846376753241.us-central1.run.app/api/v1/health
# Expected: {"status":"ok","time":"..."}

# Spot-check markets endpoint
curl "https://doomsday-api-846376753241.us-central1.run.app/api/v1/markets?active=true" | head -c 200
```

### Success criteria

- [ ] `collection-showcase /health` → HTTP 200
- [ ] `weather-api /health` → HTTP 200
- [ ] `doomsday-api /api/v1/health` → HTTP 200
- [ ] Data endpoints return non-empty arrays

---

## Quick All-Jobs Status Script

Run this to get a fast overview of all job executions:

```bash
echo "=== collection-showcase-data-sync ===" && \
gcloud run jobs executions list --job=collection-showcase-data-sync --region=us-central1 --project=future-gadget-labs-483502 --limit=3 && \
echo "=== tcgplayer-price-sync ===" && \
gcloud run jobs executions list --job=tcgplayer-price-sync --region=us-central1 --project=future-gadget-labs-483502 --limit=3 && \
echo "=== weather-sync ===" && \
gcloud run jobs executions list --job=weather-sync --region=us-central1 --limit=3 && \
echo "=== doomsday-polymarket ===" && \
gcloud run jobs executions list --job=doomsday-polymarket --region=us-central1 --limit=3 && \
echo "=== doomsday-exporter ===" && \
gcloud run jobs executions list --job=doomsday-exporter --region=us-central1 --limit=3
```

> **Note:** Jobs in `future-gadget-labs-483502` require `--project=future-gadget-labs-483502`. Jobs in `fg-polylabs` use the default gcloud project — switch with `gcloud config set project fg-polylabs` if needed.

---

## Suggested Improvements

1. **Add Cloud Monitoring alerts** — Set up alerting policies on Cloud Run job failure so you get notified without running this runbook manually. Use the [Cloud Run jobs monitoring dashboard](https://console.cloud.google.com/run/jobs) or create a log-based metric on `exit(1)` lines.

2. **Fix BQ CLI on this machine** — The `bq` CLI is broken locally (Python `absl.flags` conflict). Use the [BigQuery console](https://console.cloud.google.com/bigquery) for ad-hoc queries, or fix with:
   ```bash
   pip install --upgrade absl-py
   ```

3. **GCS write confirmation** — Both sync jobs (`collection-showcase-data-sync`, `weather-sync`) should log the bytes written per file so you can verify non-empty output from the logs alone, without needing a separate `gcloud storage ls` step.

4. **Weather GCS data gap** — As of 2026-03-24, `gs://fg-polylabs-weather-data/data/` is empty despite `weather-sync` showing a successful run. Investigate whether the sync job is writing to a different path or skipping the GCS step.

5. **Store GitHub PAT as a Secret Manager secret** — The `DATA_SYNC_PAT` for `doomsday-api` is currently stored as a plain env var (visible in `gcloud run services describe`). Move it to [Secret Manager](https://cloud.google.com/secret-manager) and reference it via `--set-secrets` to avoid accidental exposure.

6. **Expected row counts** — For the BQ data freshness check, add a baseline of expected row counts per day (e.g., "at least N products priced"). Currently the runbook only checks `> 0`; a count anomaly could indicate a partial scrape.
