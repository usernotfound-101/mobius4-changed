# Tenant_Common (Tenant A)

This folder is the common/shared MN-CSE tenant profile.

## Defaults

- CSE-ID: `/mn-cse-tenant-a`
- CSEBase: `mn-cse-tenant-a`
- HTTP: `7601`
- HTTPS: `7581`
- Registrar: `http://localhost:7599/incse`
- DB: `mobiusdb_common` (`localhost:5432`)

## Start

```bash
npm install
npm start
```

## Verify

```bash
./scripts/print_resource_tree.sh
```

## Shared Baseline

This profile is configured for shared database operation and aligns with the classic IN + Tenant_Common + Tenant_Restricted architecture.
