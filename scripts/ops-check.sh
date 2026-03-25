#!/usr/bin/env bash
# ops-check.sh — daily health check across all FutureGadgetLabs/FG-PolyLabs systems.
#
# Usage:
#   ./scripts/ops-check.sh           # check everything
#   ./scripts/ops-check.sh --jobs    # jobs only
#   ./scripts/ops-check.sh --services # services only
#   ./scripts/ops-check.sh --gcs     # GCS file timestamps only
#
# Exit code: 0 = all checks passed, 1 = one or more failures

set -euo pipefail

# ── colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; RESET='\033[0m'

PASS="${GREEN}✔${RESET}"
FAIL="${RED}✘${RESET}"
WARN="${YELLOW}⚠${RESET}"

FAILURES=0

pass() { echo -e "  ${PASS} $1"; }
fail() { echo -e "  ${FAIL} $1"; FAILURES=$((FAILURES + 1)); }
warn() { echo -e "  ${WARN} $1"; }
header() { echo -e "\n${BOLD}$1${RESET}"; }

# ── helpers ───────────────────────────────────────────────────────────────────

# Returns the STATUS prefix character (+ = success, X = failed, blank = running)
# of the most recent execution of a Cloud Run job.
last_exec_status() {
  local job=$1 project=$2
  gcloud run jobs executions list \
    --job="$job" --region=us-central1 --project="$project" --limit=1 \
    --format="value(status.conditions[0].type,status.conditions[0].status)" 2>/dev/null
}

check_job() {
  local label=$1 job=$2 project=$3 max_age_hours=${4:-26}
  local output
  output=$(gcloud run jobs executions list \
    --job="$job" --region=us-central1 --project="$project" --limit=1 \
    --format="value(status.succeededCount,status.completionTime)" 2>/dev/null)

  if [[ -z "$output" ]]; then
    fail "$label — no executions found"
    return
  fi

  local succeeded completed_at
  succeeded=$(echo "$output" | awk '{print $1}')
  completed_at=$(echo "$output" | awk '{print $2}')

  # Compute age
  local completed_epoch now_epoch age_hours
  completed_epoch=$(date -d "$completed_at" +%s 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  age_hours=$(( (now_epoch - completed_epoch) / 3600 ))

  if [[ "$succeeded" == "1" ]]; then
    if [[ $age_hours -gt $max_age_hours ]]; then
      warn "$label — last success was ${age_hours}h ago (expected within ${max_age_hours}h)"
    else
      pass "$label — completed ${age_hours}h ago"
    fi
  else
    fail "$label — last execution failed or is still running (age: ${age_hours}h). Check logs:"
    echo "    gcloud logging read \"resource.type=cloud_run_job AND resource.labels.job_name=${job}\" --project=${project} --freshness=2h --limit=20 --format='value(textPayload)'"
  fi
}

check_gcs_file() {
  local label=$1 uri=$2 max_age_hours=${3:-26} min_bytes=${4:-10}
  local output
  output=$(gcloud storage ls -l "$uri" 2>/dev/null | head -1) || true

  if [[ -z "$output" ]]; then
    fail "$label — not found at $uri"
    return
  fi

  local size
  size=$(echo "$output" | awk '{print $1}')
  local modified_at
  modified_at=$(echo "$output" | awk '{print $2}')

  local modified_epoch
  modified_epoch=$(date -d "$modified_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$modified_at" +%s 2>/dev/null || echo 0)
  local now_epoch
  now_epoch=$(date +%s)
  local age_hours=$(( (now_epoch - modified_epoch) / 3600 ))

  if [[ $age_hours -gt $max_age_hours ]]; then
    warn "$label — file is ${age_hours}h old (expected within ${max_age_hours}h), size=${size}B"
  elif [[ $size -lt $min_bytes ]]; then
    warn "$label — file present but small (${size}B) — may be empty dataset"
  else
    pass "$label — ${size}B, updated ${age_hours}h ago"
  fi
}

check_service() {
  local label=$1 url=$2
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$http_code" == "200" ]]; then
    pass "$label — HTTP $http_code"
  else
    fail "$label — HTTP $http_code (expected 200)"
  fi
}

# ── arg parsing ───────────────────────────────────────────────────────────────
CHECK_JOBS=true
CHECK_GCS=true
CHECK_SERVICES=true

if [[ $# -gt 0 ]]; then
  CHECK_JOBS=false; CHECK_GCS=false; CHECK_SERVICES=false
  for arg in "$@"; do
    case $arg in
      --jobs)     CHECK_JOBS=true ;;
      --gcs)      CHECK_GCS=true ;;
      --services) CHECK_SERVICES=true ;;
      *) echo "Unknown flag: $arg"; exit 1 ;;
    esac
  done
fi

echo -e "${BOLD}FutureGadgetLabs — Daily Ops Check${RESET}"
echo "$(date -u '+%Y-%m-%d %H:%M UTC')"

# ── 1. Cloud Run Jobs ─────────────────────────────────────────────────────────
if $CHECK_JOBS; then
  header "Cloud Run Jobs"

  echo -e " ${BOLD}collection-showcase (future-gadget-labs-483502)${RESET}"
  check_job "collection-showcase-data-sync" "collection-showcase-data-sync" "future-gadget-labs-483502" 26
  # tcgplayer-price-sync: job exists but is not yet on a schedule — add here once Cloud Scheduler is configured

  echo -e " ${BOLD}weather / doomsday (fg-polylabs)${RESET}"
  check_job "weather-sync" "weather-sync" "fg-polylabs" 26
  check_job "doomsday-polymarket" "doomsday-polymarket" "fg-polylabs" 26
  check_job "doomsday-exporter" "doomsday-exporter" "fg-polylabs" 26
fi

# ── 2. GCS File Freshness ─────────────────────────────────────────────────────
if $CHECK_GCS; then
  header "GCS File Freshness"

  echo -e " ${BOLD}gs://collection-showcase-data/${RESET}"
  check_gcs_file "collection.json"       "gs://collection-showcase-data/collection.json"   26 10
  check_gcs_file "transactions.json"     "gs://collection-showcase-data/transactions.json" 26 10
  # products and price_history may be empty [] if no data seeded yet — warn only
  check_gcs_file "products.json"         "gs://collection-showcase-data/products.json"     26 3
  check_gcs_file "price_history.json"    "gs://collection-showcase-data/price_history.json" 26 3

  echo -e " ${BOLD}gs://fg-polylabs-weather-data/${RESET}"
  check_gcs_file "tracked_cities.jsonl"  "gs://fg-polylabs-weather-data/data/tracked_cities.jsonl" 26 100
  check_gcs_file "snapshots.jsonl"       "gs://fg-polylabs-weather-data/data/snapshots.jsonl"      26 1000

  echo -e " ${BOLD}gs://fg-polylabs-doomsday/${RESET}"
  check_gcs_file "index.json"            "gs://fg-polylabs-doomsday/index.json" 26 100
fi

# ── 3. Service Health ─────────────────────────────────────────────────────────
if $CHECK_SERVICES; then
  header "Service Health"
  check_service "collection-showcase /health"      "https://collection-showcase-957536135168.us-central1.run.app/health"
  check_service "weather-api /health"              "https://weather-api-846376753241.us-central1.run.app/health"
  check_service "doomsday-api /api/v1/health"      "https://doomsday-api-846376753241.us-central1.run.app/api/v1/health"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if [[ $FAILURES -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}All checks passed.${RESET}"
else
  echo -e "${RED}${BOLD}${FAILURES} check(s) failed.${RESET}"
  exit 1
fi
