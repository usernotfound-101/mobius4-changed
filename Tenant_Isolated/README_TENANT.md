# Tenant_Isolated (Tenant B)

This folder is an isolated MN-CSE tenant profile.

## Defaults

- CSE-ID: `/mn-cse-tenant-b`
- CSEBase: `mn-cse-tenant-b`
- HTTP: `7602`
- HTTPS: `7582`
- Registrar: `http://localhost:7599/incse`
- DB: `onem2m_tenant_b` (`localhost:5433`)

## Start

```bash
npm install
npm start
```

## Verify

```bash
./scripts/print_resource_tree.sh
```

## Isolation Baseline

This profile is configured to use a dedicated database endpoint and schema (`onem2m_tenant_b`) separate from shared tenants.
