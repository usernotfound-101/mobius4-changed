#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEPLOYMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="${DEPLOYMENT_DIR}/.."
DOCKERFILE_PATH="${DEPLOYMENT_DIR}/docker/Dockerfile"

REGISTRY_URL="${REGISTRY_URL:-docker.io}"
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-usernotfound101}"
IMAGE_NAME="${IMAGE_NAME:-mobius4-changed}"
VERSION="${VERSION:-latest}"
FULL_IMAGE_TAG="${REGISTRY_URL}/${IMAGE_NAMESPACE}/${IMAGE_NAME}:${VERSION}"
LATEST_IMAGE_TAG="${REGISTRY_URL}/${IMAGE_NAMESPACE}/${IMAGE_NAME}:latest"

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}===============================================================${NC}"
echo -e "${BLUE}  Mobius4 Docker Build & Push${NC}"
echo -e "${BLUE}===============================================================${NC}"

check_prerequisites() {
  if ! command -v docker >/dev/null 2>&1; then
    print_error "Docker is not installed."
    exit 1
  fi

  if [[ ! -f "$DOCKERFILE_PATH" ]]; then
    print_error "Dockerfile not found: $DOCKERFILE_PATH"
    exit 1
  fi

  if [[ ! -f "${REPO_DIR}/package.json" ]]; then
    print_error "package.json not found in repo root."
    exit 1
  fi

  if [[ "$REGISTRY_URL" != "docker.io" ]]; then
    print_warning "Ensure you are logged in: docker login ${REGISTRY_URL}"
  fi
}

build_image() {
  print_status "Building image: ${FULL_IMAGE_TAG}"
  cd "$REPO_DIR"
  docker build -f "$DOCKERFILE_PATH" -t "$FULL_IMAGE_TAG" -t "$LATEST_IMAGE_TAG" .
}

smoke_test_image() {
  print_status "Running smoke test..."
  docker run --rm --entrypoint node "$FULL_IMAGE_TAG" -e "console.log('mobius image ok')" >/dev/null
}

push_image() {
  print_status "Pushing image: ${FULL_IMAGE_TAG}"
  docker push "$FULL_IMAGE_TAG"

  if [[ "$VERSION" != "latest" ]]; then
    print_status "Pushing image: ${LATEST_IMAGE_TAG}"
    docker push "$LATEST_IMAGE_TAG"
  fi
}

show_summary() {
  echo -e "${GREEN}Done.${NC}"
  echo -e "Image: ${FULL_IMAGE_TAG}"
  echo -e "Update deployment .env with:"
  echo -e "  MOBIUS_IMAGE=${FULL_IMAGE_TAG}"
}

main() {
  check_prerequisites
  build_image
  smoke_test_image
  push_image
  show_summary
}

main "$@"
