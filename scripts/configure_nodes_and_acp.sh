#!/usr/bin/env bash
set -euo pipefail

# Configure Tenant_Restricted with one ACP and node resources bound to that ACP.
# This script is idempotent enough for repeated runs (409/400 are tolerated on creates).

HOST="${HOST:-localhost}"
PORT="${PORT:-7603}"
CSEBASE_RN="${CSEBASE_RN:-mn-cse-tenant-c}"
ADMIN_ORIGIN="${ADMIN_ORIGIN:-SM}"
NODE_ORIGIN="${NODE_ORIGIN:-C-node-admin}"

ACP_RN="${ACP_RN:-nod_acp_restricted}"
NODE1_RN="${NODE1_RN:-node-restricted-001}"
NODE2_RN="${NODE2_RN:-node-restricted-002}"

BASE_URL="http://${HOST}:${PORT}/${CSEBASE_RN}"
ACP_SID="${CSEBASE_RN}/${ACP_RN}"

call_m2m() {
  local method="$1"
  local url="$2"
  local origin="$3"
  local ctype="${4:-}"
  local body="${5:-}"

  local req_id="setup-$(date +%s%N)"
  local out_file
  out_file="$(mktemp)"

  local code
  if [[ -n "$ctype" ]]; then
    code="$(curl -sS -o "$out_file" -w '%{http_code}' -X "$method" "$url" \
      -H "X-M2M-Origin: ${origin}" \
      -H "X-M2M-RI: ${req_id}" \
      -H "X-M2M-RVI: 4" \
      -H "Content-Type: ${ctype}" \
      -d "$body")"
  else
    code="$(curl -sS -o "$out_file" -w '%{http_code}' -X "$method" "$url" \
      -H "X-M2M-Origin: ${origin}" \
      -H "X-M2M-RI: ${req_id}" \
      -H "X-M2M-RVI: 4")"
  fi

  echo "HTTP ${code} ${method} ${url}"
  cat "$out_file"
  echo
  rm -f "$out_file"

  if [[ "$code" != "200" && "$code" != "201" && "$code" != "400" && "$code" != "409" ]]; then
    return 1
  fi
}

echo "[1/4] Check Tenant_Restricted CSE-base"
call_m2m "GET" "$BASE_URL" "$ADMIN_ORIGIN"

echo "[2/4] Create restricted ACP (${ACP_RN})"
ACP_PAYLOAD='{"m2m:acp":{"rn":"'"${ACP_RN}"'","pv":{"acr":[{"acor":["'"${NODE_ORIGIN}"'"],"acop":7},{"acor":["'"${ADMIN_ORIGIN}"'"],"acop":63}]},"pvs":{"acr":[{"acor":["'"${ADMIN_ORIGIN}"'"],"acop":63}]}}}'
call_m2m "POST" "$BASE_URL" "$ADMIN_ORIGIN" "application/json;ty=1" "$ACP_PAYLOAD"

echo "[3/4] Create restricted nodes bound to ACP (${ACP_SID})"
NODE1_PAYLOAD='{"m2m:nod":{"rn":"'"${NODE1_RN}"'","ni":"ni-'"${NODE1_RN}"'","hcl":1,"mgca":["battery"],"acpi":["'"${ACP_SID}"'"]}}'
call_m2m "POST" "$BASE_URL" "$ADMIN_ORIGIN" "application/json;ty=14" "$NODE1_PAYLOAD"

NODE2_PAYLOAD='{"m2m:nod":{"rn":"'"${NODE2_RN}"'","ni":"ni-'"${NODE2_RN}"'","hcl":1,"mgca":["location"],"acpi":["'"${ACP_SID}"'"]}}'
call_m2m "POST" "$BASE_URL" "$ADMIN_ORIGIN" "application/json;ty=14" "$NODE2_PAYLOAD"

echo "[4/4] Verify by discovery"
call_m2m "GET" "$BASE_URL?fu=1" "$ADMIN_ORIGIN"

echo "Completed. ACP and restricted nodes are configured."
