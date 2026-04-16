# Tenant Profiles (Single Boilerplate Model)

This branch is intentionally a single Mobius implementation that serves as a boilerplate.

Instead of storing multiple full copies such as `Tenant_Common`, `Tenant_Restricted`, and `Tenant_Isolated`, new MN instances are generated from the root template using profile overlays.

## Why this model

- Faster and lighter `git clone`.
- No code duplication drift across tenant folders.
- Profile behavior is applied through generated config values.

## Available profiles

Use `scripts/create_mn_instance.sh` with one of:

- `common`
- `restricted`
- `isolated`

The script sets:

- CSE-ID and CSEBase names
- HTTP/HTTPS ports (auto-resolved to avoid collisions)
- Registrar target
- DB name/user/port
- Profile ACP defaults under `cb.default_acp`

## Profile defaults

`common`:

- Base HTTP/HTTPS: `7601` / `7581`
- DB: `mobiusdb_common` (`common`) on `5432`
- ACP: `create=true`, `retrieve=true`, `update=false`, `discovery=true`

`restricted`:

- Base HTTP/HTTPS: `7603` / `7583`
- DB: `onem2m_shared` (`sm`) on `5432`
- ACP: `create=false`, `retrieve=true`, `update=false`, `discovery=false`

`isolated`:

- Base HTTP/HTTPS: `7602` / `7582`
- Base DB port: `5433` (auto-incremented if occupied)
- DB: `onem2m_<mn_name>` (`<mn_name>` normalized)
- ACP: `create=true`, `retrieve=true`, `update=false`, `discovery=true`

## Automatic MN provisioning

```bash
./scripts/create_mn_instance.sh --name tenant-d --profile common
./scripts/create_mn_instance.sh --name tenant-e --profile restricted
./scripts/create_mn_instance.sh --name tenant-f --profile isolated
```

Each created instance is tracked in `.mn_instances.json`.

The script checks both:

- currently listening local ports
- previously reserved ports in `.mn_instances.json`

This avoids future collisions when creating many MNs over time.
