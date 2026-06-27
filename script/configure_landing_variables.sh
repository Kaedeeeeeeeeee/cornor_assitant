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
  gh auth status >/dev/null
fi

for index in "${!variable_names[@]}"; do
  set_variable "${variable_names[$index]}" "${variable_values[$index]}"
done

if [[ "$RERUN_PAGES" == "1" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY RUN: would trigger %s for %s\n" "$PAGES_WORKFLOW" "$REPO"
  else
    gh workflow run "$PAGES_WORKFLOW" --repo "$REPO"
    printf "Triggered %s for %s\n" "$PAGES_WORKFLOW" "$REPO"
  fi
fi

if [[ "$CHECK_AFTER" == "1" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY RUN: would run script/check_external_readiness.py\n"
  else
    "$ROOT_DIR/script/check_external_readiness.py"
  fi
fi
