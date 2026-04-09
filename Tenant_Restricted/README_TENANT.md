# Tenant_Restricted (Tenant C)

This folder is a restricted MN-CSE tenant profile.

## Defaults

- CSE-ID: `/mn-cse-tenant-c`
- CSEBase: `mn-cse-tenant-c`
- HTTP: `7603`
- HTTPS: `7583`
- Registrar: `http://localhost:7599/incse`
- DB: `onem2m_shared` (`localhost:5432`)

## Start

```bash
npm install
npm start
```

## Verify

```bash
./scripts/print_resource_tree.sh
```

## Restriction Baseline

`config/default.json` has restricted default ACP toggles:
- create=false
- retrieve=true
- update=false
- discovery=false
