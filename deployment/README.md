# Mobius4 VM Pull Deployment

This deployment flow mirrors ctOP tenant VM behavior:
- pull prebuilt container images on the VM
- run `docker compose pull`
- run `docker compose up -d`

## Files

- `docker-compose.vm.yml`: VM runtime stack (Mobius app + PostGIS + Mosquitto)
- `env-templates/vm.env.template`: environment template
- `scripts/build-and-push.sh`: build and push image to registry
- `scripts/deploy-vm.sh`: VM-side pull and deploy

## 1) Build and push image

From repo root:

```bash
cd deployment
chmod +x scripts/build-and-push.sh scripts/deploy-vm.sh

# Example: push a versioned image
IMAGE_NAMESPACE=usernotfound101 IMAGE_NAME=mobius4-changed VERSION=v0.1.0 ./scripts/build-and-push.sh
```

## 2) Deploy on VM (pull-based)

```bash
cd deployment
cp -f env-templates/vm.env.template .env
# edit .env: MOBIUS_IMAGE, passwords, tenant identifiers, registrar settings
./scripts/deploy-vm.sh
```

The deploy script:
1. validates Docker and Compose
2. loads `.env`
3. renders `runtime/local.json` for Mobius
4. runs pull + up

## 3) Update flow

```bash
cd deployment
./scripts/deploy-vm.sh
```

Because compose references `MOBIUS_IMAGE`, every run refreshes the VM to the latest pushed image tag configured in `.env`.
