#!/usr/bin/env bash
set -euo pipefail

REPO_URL_DEFAULT="git@github.com:usernotfound-101/mobius4-changed.git"
WORKDIR_DEFAULT="${HOME}/mobius-mn-workspace"
REGISTRAR_HOST_DEFAULT="localhost"
REGISTRAR_PORT_DEFAULT="7599"
MQTT_HOST_DEFAULT="localhost"
MQTT_PORT_DEFAULT="1883"

usage() {
  cat <<'USAGE'
Usage:
  create_mn_instance.sh --name <mn-name> [options]

Required:
  --name <mn-name>              New MN instance name (example: tenant-d)

Options:
  --profile <common|restricted|isolated>
                                Profile overlay to apply (default: common)
  --repo-url <ssh-or-https-url> Repository URL to clone/pull
                                (default: git@github.com:usernotfound-101/mobius4-changed.git)
  --workdir <path>              Working directory for clone/pull
                                (default: ~/mobius-mn-workspace)
  --registrar-host <host>       IN-CSE registrar host (default: localhost)
  --registrar-port <port>       IN-CSE registrar port (default: 7599)
  --mqtt-host <host>            MQTT broker host (default: localhost)
  --mqtt-port <port>            MQTT broker port (default: 1883)
  --base-http-port <port>       Start searching free HTTP ports from this value (default: 7601)
  --base-https-port <port>      Start searching free HTTPS ports from this value (default: 7581)
  --base-db-port <port>         Start searching free DB ports from this value for isolated profile (default: 5433)
  --help                        Show this help

Behavior:
  1) Pulls latest repo (or clones it if missing)
  2) Copies root Mobius boilerplate into a new MN_<name> folder
  3) Automatically assigns free HTTP/HTTPS ports
  4) Tracks assigned ports in .mn_instances.json to avoid future collisions
  5) Applies profile-specific settings (common/restricted/isolated)
  6) Updates CSE IDs, POA, registrar target, DB values, and PM2 app name
USAGE
}

init_metadata_file() {
  local metadata_file="$1"
  if [[ ! -f "$metadata_file" ]]; then
    printf '{\n  "instances": []\n}\n' > "$metadata_file"
  fi
}

metadata_name_exists() {
  local metadata_file="$1"
  local mn_name="$2"
  node - "$metadata_file" "$mn_name" <<'NODE'
const fs = require('fs');
const [metadataFile, mnName] = process.argv.slice(2);
try {
  const data = JSON.parse(fs.readFileSync(metadataFile, 'utf8'));
  const exists = (data.instances || []).some((entry) => entry.name === mnName);
  process.exit(exists ? 0 : 1);
} catch {
  process.exit(1);
}
NODE
}

metadata_port_reserved() {
  local metadata_file="$1"
  local port="$2"
  node - "$metadata_file" "$port" <<'NODE'
const fs = require('fs');
const [metadataFile, portRaw] = process.argv.slice(2);
const port = Number(portRaw);
try {
  const data = JSON.parse(fs.readFileSync(metadataFile, 'utf8'));
  const reserved = (data.instances || []).some((entry) => {
    const ports = [entry.http_port, entry.https_port, entry.db_port].map((v) => Number(v));
    return ports.includes(port);
  });
  process.exit(reserved ? 0 : 1);
} catch {
  process.exit(1);
}
NODE
}

record_metadata_entry() {
  local metadata_file="$1"
  local mn_name="$2"
  local profile="$3"
  local instance_dir="$4"
  local cse_id="$5"
  local csebase_rn="$6"
  local http_port="$7"
  local https_port="$8"
  local db_name="$9"
  local db_user="${10}"
  local db_port="${11}"

  node - "$metadata_file" "$mn_name" "$profile" "$instance_dir" "$cse_id" "$csebase_rn" "$http_port" "$https_port" "$db_name" "$db_user" "$db_port" <<'NODE'
const fs = require('fs');
const [
  metadataFile,
  mnName,
  profile,
  instanceDir,
  cseId,
  csebaseRn,
  httpPort,
  httpsPort,
  dbName,
  dbUser,
  dbPort,
] = process.argv.slice(2);

let data = { instances: [] };
try {
  data = JSON.parse(fs.readFileSync(metadataFile, 'utf8'));
  if (!Array.isArray(data.instances)) {
    data.instances = [];
  }
} catch {
  data = { instances: [] };
}

data.instances = data.instances.filter((entry) => entry.name !== mnName);
data.instances.push({
  name: mnName,
  profile,
  instance_dir: instanceDir,
  cse_id: cseId,
  csebase_rn: csebaseRn,
  http_port: Number(httpPort),
  https_port: Number(httpsPort),
  db_name: dbName,
  db_user: dbUser,
  db_port: Number(dbPort),
  created_at: new Date().toISOString(),
});

fs.writeFileSync(metadataFile, JSON.stringify(data, null, 2) + '\n');
NODE
}

next_free_port() {
  local start="$1"
  local metadata_file="${2:-}"
  local p="$start"
  while true; do
    if ss -ltn | awk '{print $4}' | grep -Eq "[:.]${p}$"; then
      p=$((p + 1))
      continue
    fi

    if [[ -n "$metadata_file" ]] && metadata_port_reserved "$metadata_file" "$p"; then
      p=$((p + 1))
      continue
    fi

    echo "$p"
    return 0
  done
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

MN_NAME=""
PROFILE="common"
REPO_URL="$REPO_URL_DEFAULT"
WORKDIR="$WORKDIR_DEFAULT"
REGISTRAR_HOST="$REGISTRAR_HOST_DEFAULT"
REGISTRAR_PORT="$REGISTRAR_PORT_DEFAULT"
MQTT_HOST="$MQTT_HOST_DEFAULT"
MQTT_PORT="$MQTT_PORT_DEFAULT"
BASE_HTTP_PORT=7601
BASE_HTTPS_PORT=7581
BASE_DB_PORT=5433
BASE_HTTP_PORT_SET=false
BASE_HTTPS_PORT_SET=false
BASE_DB_PORT_SET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      MN_NAME="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --repo-url)
      REPO_URL="$2"
      shift 2
      ;;
    --workdir)
      WORKDIR="$2"
      shift 2
      ;;
    --registrar-host)
      REGISTRAR_HOST="$2"
      shift 2
      ;;
    --registrar-port)
      REGISTRAR_PORT="$2"
      shift 2
      ;;
    --mqtt-host)
      MQTT_HOST="$2"
      shift 2
      ;;
    --mqtt-port)
      MQTT_PORT="$2"
      shift 2
      ;;
    --base-http-port)
      BASE_HTTP_PORT="$2"
      BASE_HTTP_PORT_SET=true
      shift 2
      ;;
    --base-https-port)
      BASE_HTTPS_PORT="$2"
      BASE_HTTPS_PORT_SET=true
      shift 2
      ;;
    --base-db-port)
      BASE_DB_PORT="$2"
      BASE_DB_PORT_SET=true
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
 done

if [[ -z "$MN_NAME" ]]; then
  echo "--name is required" >&2
  usage
  exit 1
fi

case "$PROFILE" in
  common|restricted|isolated) ;;
  *)
    echo "Invalid --profile value: $PROFILE" >&2
    exit 1
    ;;
esac

require_cmd git
require_cmd node
require_cmd ss
require_cmd tar
require_cmd sed

mkdir -p "$WORKDIR"
REPO_DIR="${WORKDIR}/mobius4-changed"

if [[ -d "${REPO_DIR}/.git" ]]; then
  echo "[INFO] Pulling latest changes in ${REPO_DIR}"
  git -C "$REPO_DIR" fetch --all --prune
  git -C "$REPO_DIR" pull --ff-only
else
  echo "[INFO] Cloning ${REPO_URL} into ${REPO_DIR}"
  git clone "$REPO_URL" "$REPO_DIR"
fi

METADATA_FILE="${REPO_DIR}/.mn_instances.json"
init_metadata_file "$METADATA_FILE"

case "$PROFILE" in
  common)
    TEMPLATE_DIR="${REPO_DIR}"
    DB_USER="common"
    DB_NAME="mobiusdb_common"
    DB_PORT=5432
    ACP_CREATE=true
    ACP_RETRIEVE=true
    ACP_UPDATE=false
    ACP_DISCOVERY=true
    if [[ "$BASE_HTTP_PORT_SET" == false ]]; then
      BASE_HTTP_PORT=7601
    fi
    if [[ "$BASE_HTTPS_PORT_SET" == false ]]; then
      BASE_HTTPS_PORT=7581
    fi
    ;;
  restricted)
    TEMPLATE_DIR="${REPO_DIR}"
    DB_USER="sm"
    DB_NAME="onem2m_shared"
    DB_PORT=5432
    ACP_CREATE=false
    ACP_RETRIEVE=true
    ACP_UPDATE=false
    ACP_DISCOVERY=false
    if [[ "$BASE_HTTP_PORT_SET" == false ]]; then
      BASE_HTTP_PORT=7603
    fi
    if [[ "$BASE_HTTPS_PORT_SET" == false ]]; then
      BASE_HTTPS_PORT=7583
    fi
    ;;
  isolated)
    TEMPLATE_DIR="${REPO_DIR}"
    DB_USER="${MN_NAME//-/_}"
    DB_NAME="onem2m_${MN_NAME//-/_}"
    if [[ "$BASE_DB_PORT_SET" == false ]]; then
      BASE_DB_PORT=5433
    fi
    DB_PORT="$(next_free_port "$BASE_DB_PORT" "$METADATA_FILE")"
    ACP_CREATE=true
    ACP_RETRIEVE=true
    ACP_UPDATE=false
    ACP_DISCOVERY=true
    if [[ "$BASE_HTTP_PORT_SET" == false ]]; then
      BASE_HTTP_PORT=7602
    fi
    if [[ "$BASE_HTTPS_PORT_SET" == false ]]; then
      BASE_HTTPS_PORT=7582
    fi
    ;;
esac

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "Template directory not found: ${TEMPLATE_DIR}" >&2
  exit 1
fi

INSTANCE_DIR="${REPO_DIR}/MN_${MN_NAME}"
if [[ -e "$INSTANCE_DIR" ]]; then
  echo "Instance already exists: ${INSTANCE_DIR}" >&2
  exit 1
fi

if metadata_name_exists "$METADATA_FILE" "$MN_NAME"; then
  echo "Instance name already tracked in metadata: ${MN_NAME}" >&2
  echo "Check ${METADATA_FILE} before reusing this name." >&2
  exit 1
fi

HTTP_PORT="$(next_free_port "$BASE_HTTP_PORT" "$METADATA_FILE")"
HTTPS_PORT="$(next_free_port "$BASE_HTTPS_PORT" "$METADATA_FILE")"
CSE_ID="/mn-cse-${MN_NAME}"
CSEBASE_RN="mn-cse-${MN_NAME}"
POA_URL="http://localhost:${HTTP_PORT}"
PM2_NAME="mobius4-mn-${MN_NAME}"

echo "[INFO] Creating instance from template ${TEMPLATE_DIR}"
mkdir -p "$INSTANCE_DIR"
(
  cd "$REPO_DIR"
  tar \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='MN_*' \
    --exclude='.mn_instances.json' \
    --exclude='Tenant_Common' \
    --exclude='Tenant_Restricted' \
    --exclude='Tenant_Isolated' \
    -cf - .
) | (
  cd "$INSTANCE_DIR"
  tar -xf -
)

CONFIG_FILE="${INSTANCE_DIR}/config/default.json"
ECOSYSTEM_FILE="${INSTANCE_DIR}/ecosystem.config.js"
README_TENANT_FILE="${INSTANCE_DIR}/README_TENANT.md"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing config file: ${CONFIG_FILE}" >&2
  exit 1
fi

node - <<'NODE' "$CONFIG_FILE" "$CSE_ID" "$CSEBASE_RN" "$POA_URL" "$REGISTRAR_HOST" "$REGISTRAR_PORT" "$HTTP_PORT" "$HTTPS_PORT" "$MQTT_HOST" "$MQTT_PORT" "$DB_USER" "$DB_NAME" "$DB_PORT" "$ACP_CREATE" "$ACP_RETRIEVE" "$ACP_UPDATE" "$ACP_DISCOVERY"
const fs = require('fs');

const [configFile, cseId, csebaseRn, poaUrl, registrarHost, registrarPort, httpPort, httpsPort, mqttHost, mqttPort, dbUser, dbName, dbPort, acpCreate, acpRetrieve, acpUpdate, acpDiscovery] = process.argv.slice(2);

const cfg = JSON.parse(fs.readFileSync(configFile, 'utf8'));
cfg.cse = cfg.cse || {};
cfg.cse.cse_id = cseId;
cfg.cse.csebase_rn = csebaseRn;
cfg.cse.poa = [poaUrl];
cfg.cse.registrar = cfg.cse.registrar || {};
cfg.cse.registrar.ip = registrarHost;
cfg.cse.registrar.port = Number(registrarPort);

cfg.http = cfg.http || {};
cfg.http.port = Number(httpPort);

cfg.https = cfg.https || {};
cfg.https.port = Number(httpsPort);

cfg.mqtt = cfg.mqtt || {};
cfg.mqtt.ip = mqttHost;
cfg.mqtt.port = Number(mqttPort);

cfg.db = cfg.db || {};
cfg.db.user = dbUser;
cfg.db.name = dbName;
cfg.db.port = Number(dbPort);

cfg.cb = cfg.cb || {};
cfg.cb.default_acp = cfg.cb.default_acp || {};
cfg.cb.default_acp.create = acpCreate === 'true';
cfg.cb.default_acp.retrieve = acpRetrieve === 'true';
cfg.cb.default_acp.update = acpUpdate === 'true';
cfg.cb.default_acp.discovery = acpDiscovery === 'true';

fs.writeFileSync(configFile, JSON.stringify(cfg, null, 2) + '\n');
NODE

if [[ -f "$ECOSYSTEM_FILE" ]]; then
  sed -i "s/name: 'mobius4'/name: '${PM2_NAME}'/" "$ECOSYSTEM_FILE"
fi

if [[ ! -f "$README_TENANT_FILE" ]]; then
  cat > "$README_TENANT_FILE" <<EOF
# MN_${MN_NAME}

Profile: ${PROFILE}

This MN instance was generated from the standalone Mobius boilerplate.
EOF
fi

{
  echo
  echo "## Auto Provisioning"
  echo
  echo "This instance was auto-provisioned by scripts/create_mn_instance.sh."
  echo
  echo "- Profile: ${PROFILE}"
  echo "- CSE-ID: ${CSE_ID}"
  echo "- CSEBase: ${CSEBASE_RN}"
  echo "- HTTP: ${HTTP_PORT}"
  echo "- HTTPS: ${HTTPS_PORT}"
  echo "- Registrar: http://${REGISTRAR_HOST}:${REGISTRAR_PORT}/incse"
  echo "- DB: ${DB_NAME} (${DB_USER}@localhost:${DB_PORT})"
} >> "$README_TENANT_FILE"

record_metadata_entry \
  "$METADATA_FILE" \
  "$MN_NAME" \
  "$PROFILE" \
  "$INSTANCE_DIR" \
  "$CSE_ID" \
  "$CSEBASE_RN" \
  "$HTTP_PORT" \
  "$HTTPS_PORT" \
  "$DB_NAME" \
  "$DB_USER" \
  "$DB_PORT"

cat <<EOF
[OK] MN instance created successfully.

Repository:  ${REPO_DIR}
Instance:    ${INSTANCE_DIR}
Profile:     ${PROFILE}
CSE-ID:      ${CSE_ID}
CSEBase:     ${CSEBASE_RN}
HTTP:        ${HTTP_PORT}
HTTPS:       ${HTTPS_PORT}
Registrar:   http://${REGISTRAR_HOST}:${REGISTRAR_PORT}/incse
DB:          ${DB_NAME} (${DB_USER}@localhost:${DB_PORT})
PM2 Name:    ${PM2_NAME}
Metadata:    ${METADATA_FILE}

Next steps:
  cd ${INSTANCE_DIR}
  npm install
  npm start
EOF
