#!/usr/bin/env bash
set -euo pipefail

# Simulate the common-tenant architecture flow (Tenant A) against running IN and MN CSEs.
# Flow aligns with onem2m_architecture_guide.docx:
# 1) Verify IN and MN CSE-base reachability
# 2) Register ADN AEs on MN CSE-base
# 3) Create per-device containers and publish sample data
# 4) Create domain group (grp-air)
# 5) Run label-based discovery (fu=1, lbl=domain:air, ty=2)
# 6) Run fan-out command through group virtual resource (fopt)

IN_HOST="${IN_HOST:-localhost}"
IN_PORT="${IN_PORT:-7599}"
IN_CSEBASE_RN="${IN_CSEBASE_RN:-incse}"
IN_ADMIN_ORIGIN="${IN_ADMIN_ORIGIN:-SM}"

MN_HOST="${MN_HOST:-localhost}"
MN_PORT="${MN_PORT:-7602}"
MN_CSEBASE_RN="${MN_CSEBASE_RN:-mn-cse-tenant-b}"
MN_ADMIN_ORIGIN="${MN_ADMIN_ORIGIN:-SM}"

# Mobius4 virtual resource name for fan-out is fopt.
FANOUT_VR="${FANOUT_VR:-fopt}"

# Device setup (matching architecture guide examples)
AE1_RN="${AE1_RN:-adn-device-001}"
AE2_RN="${AE2_RN:-adn-device-002}"
AE1_ORIGIN="${AE1_ORIGIN:-C-adn-device-001}"
AE2_ORIGIN="${AE2_ORIGIN:-C-adn-device-002}"
CONTAINER_RN="${CONTAINER_RN:-sensor1}"
GROUP_RN="${GROUP_RN:-grp-air}"

OUT_DIR="${OUT_DIR:-./logs/simulations}"
mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT_FILE="$OUT_DIR/common_tenant_sim_${STAMP}.log"

log() {
  echo "[$(date +%H:%M:%S)] $*" | tee -a "$OUT_FILE" >&2
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/ }"
  printf '%s' "$s"
}

call_m2m() {
  local label="$1"
  local method="$2"
  local url="$3"
  local origin="$4"
  local ctype="$5"
  local body="${6:-}"

  local req_id="sim-${STAMP}-$(date +%s%N)"
  local body_file
  body_file="$(mktemp)"

  local code
  if [[ -n "$ctype" ]]; then
    code="$(curl -sS -o "$body_file" -w '%{http_code}' -X "$method" "$url" \
      -H "X-M2M-Origin: $origin" \
      -H "X-M2M-RI: $req_id" \
      -H "X-M2M-RVI: 4" \
      -H "Content-Type: $ctype" \
      -d "$body")"
  else
    code="$(curl -sS -o "$body_file" -w '%{http_code}' -X "$method" "$url" \
      -H "X-M2M-Origin: $origin" \
      -H "X-M2M-RI: $req_id" \
      -H "X-M2M-RVI: 4")"
  fi

  local resp
  resp="$(cat "$body_file")"
  rm -f "$body_file"

  log "$label"
  log "  $method $url"
  log "  Origin: $origin"
  log "  Status: $code"
  log "  Response: $(json_escape "$resp")"

  printf '%s\n' "$code"
}

allow_exists_or_success() {
  local status="$1"
  if [[ "$status" == "200" || "$status" == "201" ]]; then
    return 0
  fi
  # Some create calls may return 400 when rn already exists.
  if [[ "$status" == "400" || "$status" == "409" ]]; then
    log "  Note: continuing (resource may already exist)."
    return 0
  fi
  return 1
}

IN_BASE="http://${IN_HOST}:${IN_PORT}/${IN_CSEBASE_RN}"
MN_BASE="http://${MN_HOST}:${MN_PORT}/${MN_CSEBASE_RN}"

log "Starting Common Tenant architecture simulation"
log "IN base: $IN_BASE"
log "MN base: $MN_BASE"

# 1) Verify IN and MN CSE-base reachability
status="$(call_m2m "Step 1.1 - Verify IN CSE-base" "GET" "$IN_BASE" "$IN_ADMIN_ORIGIN" "" "")"
if [[ "$status" != "200" ]]; then
  log "IN reachability check failed. Expected HTTP 200."
  exit 1
fi

status="$(call_m2m "Step 1.2 - Verify MN CSE-base" "GET" "$MN_BASE" "$MN_ADMIN_ORIGIN" "" "")"
if [[ "$status" != "200" ]]; then
  log "MN reachability check failed. Expected HTTP 200."
  exit 1
fi

# 2) Register ADN AEs directly under MN CSE-base
AE1_PAYLOAD='{"m2m:ae":{"rn":"'"$AE1_RN"'","api":"Nadn.sensor.v1","rr":true,"lbl":["domain:air","type:sensor"],"poa":["http://localhost:18081"]}}'
status="$(call_m2m "Step 2.1 - Register AE ${AE1_RN}" "POST" "$MN_BASE" "$AE1_ORIGIN" "application/json;ty=2" "$AE1_PAYLOAD")"
allow_exists_or_success "$status" || { log "AE ${AE1_RN} registration failed"; exit 1; }

AE2_PAYLOAD='{"m2m:ae":{"rn":"'"$AE2_RN"'","api":"Nadn.sensor.v1","rr":true,"lbl":["domain:air","type:sensor"],"poa":["http://localhost:18082"]}}'
status="$(call_m2m "Step 2.2 - Register AE ${AE2_RN}" "POST" "$MN_BASE" "$AE2_ORIGIN" "application/json;ty=2" "$AE2_PAYLOAD")"
allow_exists_or_success "$status" || { log "AE ${AE2_RN} registration failed"; exit 1; }

# 3) Create data containers under each AE
CNT_PAYLOAD='{"m2m:cnt":{"rn":"'"$CONTAINER_RN"'"}}'
status="$(call_m2m "Step 3.1 - Create container ${AE1_RN}/${CONTAINER_RN}" "POST" "$MN_BASE/$AE1_RN" "$AE1_ORIGIN" "application/json;ty=3" "$CNT_PAYLOAD")"
allow_exists_or_success "$status" || { log "Container create failed for ${AE1_RN}"; exit 1; }

status="$(call_m2m "Step 3.2 - Create container ${AE2_RN}/${CONTAINER_RN}" "POST" "$MN_BASE/$AE2_RN" "$AE2_ORIGIN" "application/json;ty=3" "$CNT_PAYLOAD")"
allow_exists_or_success "$status" || { log "Container create failed for ${AE2_RN}"; exit 1; }

# 4) Publish sample data as contentInstances
CIN1_PAYLOAD='{"m2m:cin":{"cnf":"application/json","con":{"cmd":"sample","temp":24.1,"hum":52.2,"node":"'"$AE1_RN"'"}}}'
status="$(call_m2m "Step 4.1 - Publish data from ${AE1_RN}" "POST" "$MN_BASE/$AE1_RN/$CONTAINER_RN" "$AE1_ORIGIN" "application/json;ty=4" "$CIN1_PAYLOAD")"
allow_exists_or_success "$status" || { log "Content publish failed for ${AE1_RN}"; exit 1; }

CIN2_PAYLOAD='{"m2m:cin":{"cnf":"application/json","con":{"cmd":"sample","temp":25.0,"hum":50.9,"node":"'"$AE2_RN"'"}}}'
status="$(call_m2m "Step 4.2 - Publish data from ${AE2_RN}" "POST" "$MN_BASE/$AE2_RN/$CONTAINER_RN" "$AE2_ORIGIN" "application/json;ty=4" "$CIN2_PAYLOAD")"
allow_exists_or_success "$status" || { log "Content publish failed for ${AE2_RN}"; exit 1; }

# 5) Create domain group (group members use structured IDs in this implementation)
GROUP_PAYLOAD='{"m2m:grp":{"rn":"'"$GROUP_RN"'","mnm":100,"mid":["'"$MN_CSEBASE_RN"'/'"$AE1_RN"'","'"$MN_CSEBASE_RN"'/'"$AE2_RN"'"],"lbl":["domain:air"]}}'
status="$(call_m2m "Step 5 - Create group ${GROUP_RN}" "POST" "$MN_BASE" "$MN_ADMIN_ORIGIN" "application/json;ty=9" "$GROUP_PAYLOAD")"
allow_exists_or_success "$status" || { log "Group creation failed"; exit 1; }

# 6) Label-based discovery for air-domain AEs
status="$(call_m2m "Step 6 - Discovery (fu=1, lbl=domain:air, ty=2)" "GET" "$MN_BASE?fu=1&lbl=domain:air&ty=2" "$MN_ADMIN_ORIGIN" "" "")"
if [[ "$status" != "200" ]]; then
  log "Discovery failed"
  exit 1
fi

# 7) fan-out command using group virtual resource (fopt)
# Use a postfix so each member target resolves to <ae>/<container>.
FANOUT_PAYLOAD='{"m2m:cin":{"cnf":"application/json","con":"{\"cmd\":\"ota-update\",\"version\":\"2.1.0\"}"}}'
status="$(call_m2m "Step 7 - Fan-out command via ${GROUP_RN}/${FANOUT_VR}/${CONTAINER_RN}" "POST" "$MN_BASE/$GROUP_RN/$FANOUT_VR/$CONTAINER_RN" "$MN_ADMIN_ORIGIN" "application/json;ty=4" "$FANOUT_PAYLOAD")"
if [[ "$status" != "200" && "$status" != "201" ]]; then
  log "Fan-out command failed"
  exit 1
fi

# 8) fan-out retrieve (aggregated response from group members)
status="$(call_m2m "Step 8 - Fan-out retrieve via ${GROUP_RN}/${FANOUT_VR}/${CONTAINER_RN}" "GET" "$MN_BASE/$GROUP_RN/$FANOUT_VR/$CONTAINER_RN" "$MN_ADMIN_ORIGIN" "" "")"
if [[ "$status" != "200" ]]; then
  log "Fan-out retrieve failed"
  exit 1
fi

log "Simulation completed successfully."
log "Detailed log: $OUT_FILE"
