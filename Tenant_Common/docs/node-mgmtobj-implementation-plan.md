# Node and MgmtObj Implementation Plan

## Goal
Add oneM2M Node and MgmtObj resources to Tenant_Common so ADN devices can be represented as Node resources with management objects under each Node.

## Scope
1. Add support for ty=14 (node) and ty=13 (mgmtObj).
2. Support CRUD for node and mgmtObj at parity with existing resource handlers.
3. Keep compatibility with the current AE based simulation flow.
4. Do not introduce nonstandard mgmtObj specializations first. Start with generic mgmtObj.

## Phase 1: Core Type Wiring
1. Add type names in enums.
2. Add supported types in config.
3. Add handler routing in hosting CSE create, retrieve, update, delete switches.
4. Add these types to discovery filtering and access decision paths where type checks are explicit.

Files to update:
- config and type map: `config/default.json`, `config/enums.js`
- operation routing: `cse/hostingCSE.js`

Acceptance criteria:
- CREATE ty=14 and ty=13 are accepted by request pipeline.
- retrieve/update/delete dispatch reaches correct resource modules.

## Phase 2: Schema and Validation
1. Add Joi schemas for node create and update.
2. Add Joi schemas for mgmtObj create and update.
3. Export new schemas from res schema module.
4. Wire schema usage in request parser and resource handlers.

Suggested attribute baseline:
- node: ni, hcl, mgca and common attributes.
- mgmtObj: mgd and optional object payload fields plus common attributes.

Files to update:
- resource validation: `cse/validation/res_schema.js`
- primitive validation if needed for stricter ty list handling: `cse/validation/prim_schema.js`

Acceptance criteria:
- Invalid payloads are rejected with BAD_REQUEST.
- Minimal valid payloads for node and mgmtObj are accepted.

## Phase 3: Persistence
1. Add Sequelize models for node and mgmtObj.
2. Add PostgreSQL DDL for node and mgmtObj tables in DB init.
3. Ensure lookup entries are written consistently with sid and rn.
4. Ensure updates and deletes maintain lookup integrity and notifications.

Files to update:
- models: `models/node-model.js`, `models/mgo-model.js`
- init and tables: `db/init.js`
- optional common model index if used by project style.

Acceptance criteria:
- Rows are created in node and mgmtObj tables.
- lookup table has correct ty/sid/pi relations.

## Phase 4: Resource Handlers
1. Implement `cse/resources/node.js` following structure used by `ae.js` and `cnt.js`.
2. Implement `cse/resources/mgo.js` for generic mgmtObj handling.
3. Enforce parent child constraints.
4. Keep response primitive shape aligned with existing handlers.

Parent child constraints to enforce:
- node can be created under CSEBase.
- mgmtObj can be created under node.
- mgmtObj should not be allowed under AE or CNT in this first iteration.

Files to add:
- `cse/resources/node.js`
- `cse/resources/mgo.js`

Files to update:
- `cse/hostingCSE.js`

Acceptance criteria:
- CRUD calls for node and mgmtObj return standard rsc values.
- invalid parent type returns INVALID_CHILD_RESOURCE_TYPE.

## Phase 5: Access Control and Discovery
1. Ensure ACP evaluation works for node and mgmtObj through existing common attribute flow.
2. Verify discovery fu=1 returns node and mgmtObj URIs.
3. Verify result-content retrieval options include these resources.

Files to update:
- `cse/hostingCSE.js`
- any type filters in discovery functions inside `cse/hostingCSE.js`

Acceptance criteria:
- discovery by ty=14 returns nodes.
- discovery by ty=13 returns mgmtObjs.

## Phase 6: Tooling and Simulation Update
1. Extend simulation script to create a node per ADN and one mgmtObj under each node.
2. Keep existing AE registration path so both models can be demonstrated.
3. Extend tree printer examples to show node and mgmtObj output.

Files to update:
- `scripts/simulate_common_tenant_architecture.sh`
- `scripts/print_resource_tree.sh` only if output filtering is added later.

Acceptance criteria:
- simulation shows node and mgmtObj in tree output.
- existing AE simulation remains functional.

## Example API Sequence
1. Create node
POST /mn-cse-tenant-a with ty=14
2. Create mgmtObj under node
POST /mn-cse-tenant-a/node-adn-001 with ty=13
3. Retrieve node subtree
GET /mn-cse-tenant-a/node-adn-001?rcn=4&lvl=1
4. Discover management objects
GET /mn-cse-tenant-a?fu=1&ty=13

## Recommended Rollout
1. Implement and test in Tenant_Common only.
2. After validation, port the same changes to IN and any tenant variants.
3. Reinitialize DB in test environment when table schema changes are introduced.

## Test Checklist
1. CREATE/RETRIEVE/UPDATE/DELETE node success path.
2. CREATE/RETRIEVE/UPDATE/DELETE mgmtObj success path.
3. invalid parent for mgmtObj rejected.
4. duplicate rn conflict checks for node and mgmtObj.
5. discovery and rcn behavior.
6. access decision with admin and non admin origins.
