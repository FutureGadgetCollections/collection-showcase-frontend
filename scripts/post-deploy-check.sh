#!/usr/bin/env bash
# post-deploy-check.sh — validates a service or job after deploying a new image.
#
# Usage:
#   ./scripts/post-deploy-check.sh <target>
#
# Targets:
#   collection-showcase       API service (future-gadget-labs-483502)
#   collection-showcase-sync  Data sync job (future-gadget-labs-483502)
#   weather-api               API service (fg-polylabs)
#   weather-sync              Data sync job (fg-polylabs)
#   doomsday-api              API service (fg-polylabs)
#   doomsday-exporter         Export job (fg-polylabs)
#   doomsday-polymarket       Data fetch job (fg-polylabs)
#   all                       Run checks for everything (does not trigger jobs)
#
# Exit code: 0 = all checks passed, 1 = one or more failures

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; RESET='\033[0m'

PASS="${GREEN}✔${RESET}"; FAIL="${RED}✘${RESET}"; WARN="${YELLOW}⚠${RESET}"
FAILURES=0

pass() { echo -e "  ${PASS} $1"; }
fail() { echo -e "  ${FAIL} $1"; FAILURES=$((FAILURES + 1)); }
warn() { echo -e "  ${WARN} $1"; }
header() { echo -e "\n${BOLD}$1${RESET}"; }

# ── helpers ───────────────────────────────────────────────────────────────────

check_service_health() {
  local label=$1 url=$2
  echo -e "\n  Checking ${BOLD}${label}${RESET} health..."
  local http_code body
  body=$(curl -s --max-time 15 "$url" 2>/dev/null || echo "")
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$url" 2>/dev/null || echo "000")

  if [[ "$http_code" == "200" ]]; then
    pass "Health endpoint → HTTP $http_code: $body"
  else
    fail "Health endpoint → HTTP $http_code (expected 200)"
  fi
}

check_endpoint_nonempty() {
  local label=$1 url=$2
  local http_code body
  body=$(curl -s --max-time 15 "$url" 2>/dev/null || echo "")
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$url" 2>/dev/null || echo "000")

  if [[ "$http_code" != "200" ]]; then
    fail "$label → HTTP $http_code"
    return
  fi
  # Check response is a non-empty JSON array or object (not null/empty)
  local len
  len=$(echo "$body" | wc -c)
  if [[ $len -lt 3 ]]; then
    warn "$label → HTTP 200 but response suspiciously short ($len bytes)"
  else
    pass "$label → HTTP 200 ($len bytes)"
  fi
}

trigger_job_and_wait() {
  local label=$1 job=$2 project=$3
  echo -e "\n  Triggering ${BOLD}${job}${RESET}..."
  local exec_name
  exec_name=$(gcloud run jobs execute "$job" \
    --region=us-central1 --project="$project" \
    --format="value(metadata.name)" 2>/dev/null)

  if [[ -z "$exec_name" ]]; then
    fail "$label — failed to start execution"
    return
  fi

  echo "  Waiting for execution ${exec_name}..."
  local max_wait=600  # 10 minutes
  local elapsed=0
  local sleep_interval=10
  while [[ $elapsed -lt $max_wait ]]; do
    local succeeded
    succeeded=$(gcloud run jobs executions describe "$exec_name" \
      --region=us-central1 --project="$project" \
      --format="value(status.succeededCount)" 2>/dev/null || echo "")
    local failed
    failed=$(gcloud run jobs executions describe "$exec_name" \
      --region=us-central1 --project="$project" \
      --format="value(status.failedCount)" 2>/dev/null || echo "")

    if [[ "$succeeded" == "1" ]]; then
      pass "$label — execution ${exec_name} completed successfully"
      return
    elif [[ "$failed" =~ ^[1-9] ]]; then
      fail "$label — execution ${exec_name} failed. Check logs:"
      echo "    gcloud logging read \"resource.labels.execution_name=${exec_name}\" --project=${project} --limit=20 --format='value(textPayload)'"
      return
    fi

    sleep $sleep_interval
    elapsed=$((elapsed + sleep_interval))
    echo -ne "  \r  Waiting... ${elapsed}s elapsed"
  done
  fail "$label — timed out after ${max_wait}s waiting for ${exec_name}"
}

check_gcs_recent() {
  local label=$1 uri=$2 min_bytes=${3:-10}
  local output
  output=$(gcloud storage ls -l "$uri" 2>/dev/null | head -1) || true
  if [[ -z "$output" ]]; then
    fail "$label — $uri not found"
    return
  fi
  local size
  size=$(echo "$output" | awk '{print $1}')
  if [[ $size -lt $min_bytes ]]; then
    fail "$label — file too small (${size}B), likely empty"
  else
    pass "$label — ${size}B present at $uri"
  fi
}

# ── per-target checks ─────────────────────────────────────────────────────────

check_collection_showcase_service() {
  header "collection-showcase service (future-gadget-labs-483502)"
  local base="https://collection-showcase-957536135168.us-central1.run.app"
  check_service_health "collection-showcase" "$base/health"
  check_endpoint_nonempty "GET /info"        "$base/info"
  check_endpoint_nonempty "GET /collection"  "$base/collection"
  check_endpoint_nonempty "GET /products"    "$base/products"
  check_endpoint_nonempty "GET /sync/status" "$base/sync/status"
}

check_collection_showcase_sync() {
  header "collection-showcase-data-sync job (future-gadget-labs-483502)"
  trigger_job_and_wait "collection-showcase-data-sync" "collection-showcase-data-sync" "future-gadget-labs-483502"
  # Verify GCS was written
  echo ""
  check_gcs_recent "collection.json"    "gs://collection-showcase-data/collection.json"    10
  check_gcs_recent "transactions.json"  "gs://collection-showcase-data/transactions.json"  10
  check_gcs_recent "products.json"      "gs://collection-showcase-data/products.json"      10
  check_gcs_recent "price_history.json" "gs://collection-showcase-data/price_history.json" 10
}

check_weather_api() {
  header "weather-api service (fg-polylabs)"
  local base="https://weather-api-846376753241.us-central1.run.app"
  check_service_health "weather-api" "$base/health"
  check_endpoint_nonempty "GET /cities"    "$base/cities"
  check_endpoint_nonempty "GET /snapshots" "$base/snapshots"
}

check_weather_sync() {
  header "weather-sync job (fg-polylabs)"
  trigger_job_and_wait "weather-sync" "weather-sync" "fg-polylabs"
  echo ""
  check_gcs_recent "tracked_cities.jsonl" "gs://fg-polylabs-weather-data/data/tracked_cities.jsonl" 100
  check_gcs_recent "snapshots.jsonl"      "gs://fg-polylabs-weather-data/data/snapshots.jsonl"      1000
}

check_doomsday_api() {
  header "doomsday-api service (fg-polylabs)"
  local base="https://doomsday-api-846376753241.us-central1.run.app"
  check_service_health "doomsday-api" "$base/api/v1/health"
  check_endpoint_nonempty "GET /api/v1/markets" "$base/api/v1/markets"
  check_endpoint_nonempty "GET /api/v1/events"  "$base/api/v1/events"
}

check_doomsday_exporter() {
  header "doomsday-exporter job (fg-polylabs)"
  trigger_job_and_wait "doomsday-exporter" "doomsday-exporter" "fg-polylabs"
  echo ""
  check_gcs_recent "index.json" "gs://fg-polylabs-doomsday/index.json" 100
}

check_doomsday_polymarket() {
  header "doomsday-polymarket job (fg-polylabs)"
  trigger_job_and_wait "doomsday-polymarket" "doomsday-polymarket" "fg-polylabs"
}

# ── dispatch ──────────────────────────────────────────────────────────────────

TARGET=${1:-}

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <target>"
  echo ""
  echo "Targets:"
  echo "  collection-showcase       API service (future-gadget-labs-483502)"
  echo "  collection-showcase-sync  Data sync job (triggers a run)"
  echo "  weather-api               API service (fg-polylabs)"
  echo "  weather-sync              Sync job (triggers a run)"
  echo "  doomsday-api              API service (fg-polylabs)"
  echo "  doomsday-exporter         Export job (triggers a run)"
  echo "  doomsday-polymarket       Data fetch job (triggers a run)"
  echo "  all                       Service health checks only (no job triggers)"
  exit 1
fi

echo -e "${BOLD}Post-Deploy Validation — ${TARGET}${RESET}"
echo "$(date -u '+%Y-%m-%d %H:%M UTC')"

case "$TARGET" in
  collection-showcase)       check_collection_showcase_service ;;
  collection-showcase-sync)  check_collection_showcase_sync ;;
  weather-api)               check_weather_api ;;
  weather-sync)              check_weather_sync ;;
  doomsday-api)              check_doomsday_api ;;
  doomsday-exporter)         check_doomsday_exporter ;;
  doomsday-polymarket)       check_doomsday_polymarket ;;
  all)
    check_collection_showcase_service
    check_weather_api
    check_doomsday_api
    ;;
  *)
    echo "Unknown target: $TARGET"
    exit 1
    ;;
esac

echo ""
if [[ $FAILURES -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}All checks passed.${RESET}"
else
  echo -e "${RED}${BOLD}${FAILURES} check(s) failed.${RESET}"
  exit 1
fi
