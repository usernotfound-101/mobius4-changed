# Tenant Profiles: Restricted and Isolated

This repository now includes two runnable tenant variants:

- `Tenant_Restricted` (Tenant C)
- `Tenant_Isolated` (Tenant B)

## Tenant_Restricted (Tenant C)

Purpose:
- Runs as MN-CSE with tighter default access policy behavior.
- Uses a shared PostgreSQL instance/database model.

Configured defaults:
- CSE-ID: `/mn-cse-tenant-c`
- CSEBase RN: `mn-cse-tenant-c`
- HTTP: `7603`
- HTTPS: `7583`
- Registrar target: `http://localhost:7599/incse`
- DB: `onem2m_shared` on `localhost:5432`
- Restricted default ACP knobs:
  - `cb.default_acp.create=false`
  - `cb.default_acp.retrieve=true`
  - `cb.default_acp.update=false`
  - `cb.default_acp.discovery=false`

## Tenant_Isolated (Tenant B)

Purpose:
- Runs as MN-CSE with dedicated DB endpoint.
- Keeps tenant resource data isolated from shared tenant DB.

Configured defaults:
- CSE-ID: `/mn-cse-tenant-b`
- CSEBase RN: `mn-cse-tenant-b`
- HTTP: `7602`
- HTTPS: `7582`
- Registrar target: `http://localhost:7599/incse`
- DB: `onem2m_tenant_b` on `localhost:5433`

## Shared DB Bootstrap Compatibility

`db/init.js` is patched to look up existing CSEBase by `sid`:
- `SELECT ri FROM cb WHERE ty = 5 AND sid = $1`

This allows multiple tenant CSE processes to share one database without incorrectly reusing another tenant's CSEBase record.

## Run Order

1. Start IN-CSE (`/incse`) first.
2. Start `Tenant_Restricted` and/or `Tenant_Isolated`.
3. Verify tree output with each tenant's `scripts/print_resource_tree.sh`.

## Notes

- If databases do not exist yet, create them first (`onem2m_shared`, `onem2m_tenant_b`) and grant user permissions.
- `Tenant_Isolated` is configured for a dedicated PostgreSQL instance/port (`5433`).
