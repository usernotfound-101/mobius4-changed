#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEPLOYMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${DEPLOYMENT_DIR}/.env"
COMPOSE_FILE="${DEPLOYMENT_DIR}/docker-compose.vm.yml"
RUNTIME_LOCAL_CONFIG="${DEPLOYMENT_DIR}/runtime/local.json"

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}===============================================================${NC}"
echo -e "${BLUE}  Mobius4 VM Deployment${NC}"
echo -e "${BLUE}===============================================================${NC}"

check_docker() {
  print_status "Checking Docker installation..."
  if ! command -v docker >/dev/null 2>&1; then
    print_error "Docker is not installed."
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    print_error "Docker daemon is not running."
    exit 1
  fi
}

check_compose() {
  print_status "Checking Docker Compose..."
  if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
  elif docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
  else
    print_error "Docker Compose is not available."
    exit 1
  fi
}

setup_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    print_warning ".env not found. Creating from template..."
    cp "${DEPLOYMENT_DIR}/env-templates/vm.env.template" "$ENV_FILE"
    print_warning "Edit ${ENV_FILE} before deploying (image tag, passwords, ports)."
    exit 1
  fi

  print_status "Using environment file: ${ENV_FILE}"
  # shellcheck disable=SC1090
  source "$ENV_FILE"
}

validate_env() {
  local required=(TENANT_ID MOBIUS_IMAGE MOBIUS_DB_PASSWORD MOBIUS_CSE_ID MOBIUS_BASE_RN)
  for key in "${required[@]}"; do
    if [[ -z "${!key:-}" ]]; then
      print_error "Missing required value in .env: ${key}"
      exit 1
    fi
  done

  if grep -q "change_this" "$ENV_FILE"; then
    print_error "Default placeholder secrets still present in ${ENV_FILE}."
    exit 1
  fi
}

render_local_config() {
  print_status "Generating runtime config for Mobius app..."
  mkdir -p "${DEPLOYMENT_DIR}/runtime"

  cat > "$RUNTIME_LOCAL_CONFIG" <<EOF
{
  "cse": {
    "cse_type": ${CSE_TYPE:-2},
    "cse_id": "${MOBIUS_CSE_ID}",
    "csebase_rn": "${MOBIUS_BASE_RN}",
    "poa": [
      "http://${TENANT_VM_IP}:${MOBIUS_HTTP_PORT}"
    ],
    "registrar": {
      "cse_id": "${REGISTRAR_CSE_ID}",
      "csebase_rn": "${REGISTRAR_BASE_RN}",
      "ip": "${REGISTRAR_HOST}",
      "port": ${REGISTRAR_PORT}
    },
    "admin": "${MOBIUS_ADMIN:-SM}"
  },
  "http": {
    "port": ${MOBIUS_CONTAINER_HTTP_PORT}
  },
  "https": {
    "port": ${MOBIUS_CONTAINER_HTTPS_PORT}
  },
  "mqtt": {
    "ip": "${MQTT_HOST:-mosquitto}",
    "port": ${MQTT_BROKER_PORT:-1883}
  },
  "db": {
    "host": "mobius_db",
    "port": 5432,
    "name": "${MOBIUS_DB_NAME}",
    "user": "${MOBIUS_DB_USER}",
    "pw": "${MOBIUS_DB_PASSWORD}"
  },
  "logging": {
    "level": "${LOG_LEVEL:-info}"
  },
  "metrics": {
    "enabled": ${METRICS_ENABLED:-false}
  },
  "security": {
    "helmet": {
      "enabled": ${HELMET_ENABLED:-false}
    },
    "rateLimit": {
      "enabled": ${RATE_LIMIT_ENABLED:-false}
    }
  }
}
EOF
}

deploy() {
  print_status "Pulling latest images..."
  $COMPOSE_CMD -f "$COMPOSE_FILE" pull

  print_status "Starting Mobius VM services..."
  $COMPOSE_CMD -f "$COMPOSE_FILE" up -d
}

show_status() {
  print_status "Deployment completed."
  echo -e "${YELLOW}Useful commands:${NC}"
  echo -e "  $COMPOSE_CMD -f ${COMPOSE_FILE} ps"
  echo -e "  $COMPOSE_CMD -f ${COMPOSE_FILE} logs -f mobius_app"
  echo -e "  $COMPOSE_CMD -f ${COMPOSE_FILE} pull && $COMPOSE_CMD -f ${COMPOSE_FILE} up -d"
}

main() {
  check_docker
  check_compose
  setup_env
  validate_env
  render_local_config
  deploy
  show_status
}

main "$@"
