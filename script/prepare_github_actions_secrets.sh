#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-/tmp/peek-github-actions-secrets}"
KEYCHAIN_PATH="${PEEK_SIGNING_KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}"
APP_CERT_NAME="${PEEK_APP_CERT_NAME:-Apple Distribution: SHIFENG ZHANG (Y4FV6WUU4V)}"
INSTALLER_CERT_NAME="${PEEK_INSTALLER_CERT_NAME:-3rd Party Mac Developer Installer: SHIFENG ZHANG (Y4FV6WUU4V)}"
PROFILE_PATH="${PEEK_PROVISION_PROFILE_PATH:-$HOME/Downloads/Corner_Peek_Mac_App_Store.provisionprofile}"

if [[ -f "$ROOT_DIR/.env.asc" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env.asc"
  set +a
fi

P12_PASSWORD="${PEEK_P12_PASSWORD:-$(openssl rand -base64 24 | tr -d '\n')}"
KEYCHAIN_PASSWORD="${PEEK_KEYCHAIN_PASSWORD:-$(openssl rand -base64 24 | tr -d '\n')}"
ASC_KEY_PATH="${ASC_KEY_PATH:-${APP_STORE_CONNECT_API_KEY_PATH:-}}"

if [[ ! -f "$PROFILE_PATH" ]]; then
  echo "Missing provisioning profile: $PROFILE_PATH" >&2
  exit 1
fi

if [[ -z "${ASC_KEY_ID:-}" ]]; then
  echo "Missing ASC_KEY_ID. Set it in .env.asc or the shell environment." >&2
  exit 1
fi

if [[ -z "${ASC_ISSUER_ID:-}" ]]; then
  echo "Missing ASC_ISSUER_ID. Set it in .env.asc or the shell environment." >&2
  exit 1
fi

if [[ -z "$ASC_KEY_PATH" || ! -f "$ASC_KEY_PATH" ]]; then
  echo "Missing ASC key file. Set ASC_KEY_PATH in .env.asc or the shell environment." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

app_p12="$OUT_DIR/app-certificate.p12"
installer_p12="$OUT_DIR/installer-certificate.p12"
secrets_env="$OUT_DIR/github-actions-secrets.env"

security export \
  -k "$KEYCHAIN_PATH" \
  -t identities \
  -f pkcs12 \
  -P "$P12_PASSWORD" \
  -c "$APP_CERT_NAME" \
  -o "$app_p12"

security export \
  -k "$KEYCHAIN_PATH" \
  -t identities \
  -f pkcs12 \
  -P "$P12_PASSWORD" \
  -c "$INSTALLER_CERT_NAME" \
  -o "$installer_p12"

{
  printf "PEEK_APP_CERTIFICATE_BASE64=%s\n" "$(base64 < "$app_p12" | tr -d '\n')"
  printf "PEEK_INSTALLER_CERTIFICATE_BASE64=%s\n" "$(base64 < "$installer_p12" | tr -d '\n')"
  printf "PEEK_P12_PASSWORD=%s\n" "$P12_PASSWORD"
  printf "PEEK_PROVISION_PROFILE_BASE64=%s\n" "$(base64 < "$PROFILE_PATH" | tr -d '\n')"
  printf "PEEK_KEYCHAIN_PASSWORD=%s\n" "$KEYCHAIN_PASSWORD"
  printf "PEEK_ASC_KEY_ID=%s\n" "$ASC_KEY_ID"
  printf "PEEK_ASC_ISSUER_ID=%s\n" "$ASC_ISSUER_ID"
  printf "PEEK_ASC_KEY_CONTENT_BASE64=%s\n" "$(base64 < "$ASC_KEY_PATH" | tr -d '\n')"
} > "$secrets_env"

chmod 600 "$app_p12" "$installer_p12" "$secrets_env"

cat <<EOF
Prepared GitHub Actions secret values at:
  $secrets_env

Sensitive local files:
  $app_p12
  $installer_p12

Do not commit these files. Upload the values as GitHub Actions repository secrets, then delete this directory.
EOF
