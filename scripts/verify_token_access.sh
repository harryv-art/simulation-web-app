#!/usr/bin/env bash
set -euo pipefail

# This script compares access behavior for:
# 1) OIDC exchange token (/access/api/v1/oidc/token)
# 2) Admin-issued token (/access/api/v1/tokens) with same username/scope

required_vars=(
  JF_URL
  OIDC_EXCHANGE_TOKEN
  TARGET_DENY_URL
)

for v in "${required_vars[@]}"; do
  if [ -z "${!v:-}" ]; then
    echo "Missing required env var: $v" >&2
    exit 1
  fi
done

timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "[INFO] UTC timestamp: ${timestamp}"

if [ -n "${TARGET_ALLOW_URL:-}" ]; then
  oidc_allow_code="$(curl -sS -o /tmp/oidc-allow.bin -w '%{http_code}' \
    -H "Authorization: Bearer ${OIDC_EXCHANGE_TOKEN}" \
    "${TARGET_ALLOW_URL}")"
  echo "[RESULT] OIDC token ALLOW URL status: ${oidc_allow_code}"
fi

if [ -n "${TARGET_WRITE_URL:-}" ]; then
  oidc_write_code="$(curl -sS -o /tmp/oidc-write.out -w '%{http_code}' \
    -X PUT \
    -H "Authorization: Bearer ${OIDC_EXCHANGE_TOKEN}" \
    -H "Content-Type: text/plain" \
    --data "oidc-write-test ${timestamp}" \
    "${TARGET_WRITE_URL}")"
  echo "[RESULT] OIDC token WRITE URL status: ${oidc_write_code}"

  oidc_read_back_code="$(curl -sS -o /tmp/oidc-read-back.bin -w '%{http_code}' \
    -H "Authorization: Bearer ${OIDC_EXCHANGE_TOKEN}" \
    "${TARGET_WRITE_URL}")"
  echo "[RESULT] OIDC token READ-BACK URL status: ${oidc_read_back_code}"
fi

oidc_deny_code="$(curl -sS -o /tmp/oidc-deny.bin -w '%{http_code}' \
  -H "Authorization: Bearer ${OIDC_EXCHANGE_TOKEN}" \
  "${TARGET_DENY_URL}")"
echo "[RESULT] OIDC token DENY URL status: ${oidc_deny_code}"

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

  if [ -n "${TARGET_ALLOW_URL:-}" ]; then
    admin_allow_code="$(curl -sS -o /tmp/admin-allow.bin -w '%{http_code}' \
      -H "Authorization: Bearer ${admin_token}" \
      "${TARGET_ALLOW_URL}")"
    echo "[RESULT] Admin token ALLOW URL status: ${admin_allow_code}"
  fi

  if [ -n "${TARGET_WRITE_URL:-}" ]; then
    admin_write_code="$(curl -sS -o /tmp/admin-write.out -w '%{http_code}' \
      -X PUT \
      -H "Authorization: Bearer ${admin_token}" \
      -H "Content-Type: text/plain" \
      --data "admin-write-test ${timestamp}" \
      "${TARGET_WRITE_URL}")"
    echo "[RESULT] Admin token WRITE URL status: ${admin_write_code}"
  fi

  admin_deny_code="$(curl -sS -o /tmp/admin-deny.bin -w '%{http_code}' \
    -H "Authorization: Bearer ${admin_token}" \
    "${TARGET_DENY_URL}")"
  echo "[RESULT] Admin token DENY URL status: ${admin_deny_code}"
fi

echo "[DONE] Verification complete"
