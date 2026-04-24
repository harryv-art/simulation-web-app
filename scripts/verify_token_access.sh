#!/usr/bin/env bash
set -euo pipefail

# This script compares read access behavior for:
# 1) OIDC exchange token (/access/api/v1/oidc/token)
# 2) Admin-issued token (/access/api/v1/tokens) with same username/scope

required_vars=(
  JF_URL
  OIDC_EXCHANGE_TOKEN
  NPM_TEST_URL
)

for v in "${required_vars[@]}"; do
  if [ -z "${!v:-}" ]; then
    echo "Missing required env var: $v" >&2
    exit 1
  fi
done

timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "[INFO] UTC timestamp: ${timestamp}"

oidc_code="$(curl -sS -o /tmp/oidc-verify.bin -w '%{http_code}' \
  -H "Authorization: Bearer ${OIDC_EXCHANGE_TOKEN}" \
  "${NPM_TEST_URL}")"
echo "[RESULT] OIDC exchange token fetch status: ${oidc_code}"

if [ -n "${JF_ADMIN_TOKEN:-}" ]; then
  admin_resp="$(curl -sS -X POST "${JF_URL}/access/api/v1/tokens" \
    -H "Authorization: Bearer ${JF_ADMIN_TOKEN}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "username=github-simulation-web-app" \
    --data-urlencode "scope=applied-permissions/groups:github-repo-simulation-web-app" \
    --data-urlencode "expires_in=3600")"
  admin_token="$(echo "$admin_resp" | jq -r '.access_token')"
  if [ -z "$admin_token" ] || [ "$admin_token" = "null" ]; then
    echo "[ERROR] Could not create admin-issued token"
    echo "$admin_resp"
    exit 1
  fi

  admin_code="$(curl -sS -o /tmp/admin-verify.bin -w '%{http_code}' \
    -H "Authorization: Bearer ${admin_token}" \
    "${NPM_TEST_URL}")"
  echo "[RESULT] Admin-issued token fetch status: ${admin_code}"
fi

echo "[DONE] Verification complete"
