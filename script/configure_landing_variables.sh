#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${REPO:-Kaedeeeeeeeeee/cornor_assitant}"
PAGES_WORKFLOW="${PAGES_WORKFLOW:-pages.yml}"
DRY_RUN=0
RERUN_PAGES=0
CHECK_AFTER=0

usage() {
  cat >&2 <<'USAGE'
usage: script/configure_landing_variables.sh [--dry-run] [--rerun-pages] [--check-after]

Reads these optional environment variables and writes the non-empty values to
GitHub repository variables:

  PEEK_GA_MEASUREMENT_ID          GA4 measurement id, e.g. G-XXXXXXXXXX
  PEEK_GOOGLE_SITE_VERIFICATION   Google Search Console meta content value
  PEEK_BING_SITE_VERIFICATION     Bing Webmaster Tools msvalidate.01 content value

Examples:

  PEEK_GA_MEASUREMENT_ID=G-XXXXXXXXXX \
    script/configure_landing_variables.sh --dry-run

  PEEK_GOOGLE_SITE_VERIFICATION=google_token \
  PEEK_BING_SITE_VERIFICATION=bing_token \
    script/configure_landing_variables.sh --rerun-pages --check-after
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --rerun-pages)
      RERUN_PAGES=1
      ;;
    --check-after)
      CHECK_AFTER=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf "Unknown option: %s\n" "$1" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

require_command() {
  local command="$1"
  if ! command -v "$command" >/dev/null 2>&1; then
    printf "Missing required command: %s\n" "$command" >&2
    exit 1
  fi
}

latest_pages_run_json() {
  gh run list \
    --repo "$REPO" \
    --workflow "$PAGES_WORKFLOW" \
    --limit 1 \
    --json databaseId,status,conclusion,url
}

extract_run_field() {
  local field="$1"
  python3 -c 'import json, sys
raw = sys.stdin.read()
try:
    data = json.loads(raw) if raw.strip() else []
except json.JSONDecodeError:
    data = []
value = data[0].get(sys.argv[1], "") if data else ""
print("" if value is None else value)' "$field"
}

wait_for_pages_workflow() {
  local previous_run_id="$1"
  local attempts=90
  local delay_seconds=5
  local attempt

  printf "Waiting for new %s run to complete...\n" "$PAGES_WORKFLOW"

  for ((attempt = 1; attempt <= attempts; attempt += 1)); do
    local run_json run_id status conclusion url
    run_json="$(latest_pages_run_json || true)"
    run_id="$(printf "%s" "$run_json" | extract_run_field databaseId)"
    status="$(printf "%s" "$run_json" | extract_run_field status)"
    conclusion="$(printf "%s" "$run_json" | extract_run_field conclusion)"
    url="$(printf "%s" "$run_json" | extract_run_field url)"

    if [[ -n "$run_id" && "$run_id" != "$previous_run_id" ]]; then
      printf "Pages run %s status=%s conclusion=%s\n" "$run_id" "${status:-unknown}" "${conclusion:-pending}"
      if [[ "$status" == "completed" ]]; then
        if [[ "$conclusion" == "success" ]]; then
          printf "Pages run completed successfully: %s\n" "$url"
          return 0
        fi
        printf "Pages run did not succeed: %s\n" "$url" >&2
        exit 1
      fi
    fi

    sleep "$delay_seconds"
  done

  printf "Timed out waiting for a new %s run to complete.\n" "$PAGES_WORKFLOW" >&2
  exit 1
}

validate_value() {
  local name="$1"
  local value="$2"
  local pattern="$3"
  local hint="$4"

  if [[ ! "$value" =~ $pattern ]]; then
    printf "%s has invalid format. Expected: %s\n" "$name" "$hint" >&2
    exit 1
  fi
}

set_variable() {
  local name="$1"
  local value="$2"
  local length=${#value}

  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY RUN: would set %s in %s (length=%s)\n" "$name" "$REPO" "$length"
  else
    gh variable set "$name" --repo "$REPO" --body "$value" >/dev/null
    printf "Set %s in %s (length=%s)\n" "$name" "$REPO" "$length"
  fi
}

declare -a variable_names=()
declare -a variable_values=()

add_variable_if_present() {
  local name="$1"
  local value="${2:-}"
  local pattern="$3"
  local hint="$4"

  value="$(printf "%s" "$value" | xargs)"
  if [[ -z "$value" ]]; then
    return
  fi

  validate_value "$name" "$value" "$pattern" "$hint"
  variable_names+=("$name")
  variable_values+=("$value")
}

add_variable_if_present \
  "PEEK_GA_MEASUREMENT_ID" \
  "${PEEK_GA_MEASUREMENT_ID:-}" \
  '^G-[A-Z0-9]+$' \
  'G- followed by uppercase letters or digits'

add_variable_if_present \
  "PEEK_GOOGLE_SITE_VERIFICATION" \
  "${PEEK_GOOGLE_SITE_VERIFICATION:-}" \
  '^[A-Za-z0-9_-]+$' \
  'letters, digits, underscore, or hyphen'

add_variable_if_present \
  "PEEK_BING_SITE_VERIFICATION" \
  "${PEEK_BING_SITE_VERIFICATION:-}" \
  '^[A-Za-z0-9_-]+$' \
  'letters, digits, underscore, or hyphen'

if [[ "${#variable_names[@]}" -eq 0 ]]; then
  printf "No landing variables were provided.\n\n" >&2
  usage
  exit 2
fi

if [[ "$DRY_RUN" != "1" ]]; then
  require_command gh
  require_command python3
  gh auth status >/dev/null
fi

for index in "${!variable_names[@]}"; do
  set_variable "${variable_names[$index]}" "${variable_values[$index]}"
done

previous_pages_run_id=""
if [[ "$RERUN_PAGES" == "1" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY RUN: would trigger %s for %s\n" "$PAGES_WORKFLOW" "$REPO"
  else
    previous_pages_run_id="$(latest_pages_run_json | extract_run_field databaseId)"
    gh workflow run "$PAGES_WORKFLOW" --repo "$REPO"
    printf "Triggered %s for %s\n" "$PAGES_WORKFLOW" "$REPO"
    if [[ "$CHECK_AFTER" == "1" ]]; then
      wait_for_pages_workflow "$previous_pages_run_id"
    fi
  fi
fi

if [[ "$CHECK_AFTER" == "1" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY RUN: would run script/check_external_readiness.py\n"
  else
    "$ROOT_DIR/script/check_external_readiness.py"
  fi
fi
