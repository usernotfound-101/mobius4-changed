#!/usr/bin/env bash
set -euo pipefail

# Print oneM2M resource tree using discovery (fu=1) from a target CSEBase.
# Defaults target Tenant_Common, but can be overridden with env vars.

HOST="${HOST:-localhost}"
PORT="${PORT:-7601}"
CSEBASE_RN="${CSEBASE_RN:-mn-cse-tenant-a}"
ORIGIN="${ORIGIN:-SM}"
RVI="${RVI:-4}"

URL="http://${HOST}:${PORT}/${CSEBASE_RN}?fu=1"
TMP_JSON="$(mktemp)"
cleanup() { rm -f "$TMP_JSON"; }
trap cleanup EXIT

STATUS="$(curl -sS -o "$TMP_JSON" -w '%{http_code}' \
  -X GET "$URL" \
  -H "X-M2M-Origin: ${ORIGIN}" \
  -H "X-M2M-RI: tree-$(date +%s%N)" \
  -H "X-M2M-RVI: ${RVI}")"

if [[ "$STATUS" != "200" ]]; then
  echo "Failed to fetch discovery list"
  echo "URL: $URL"
  echo "HTTP: $STATUS"
  echo "Response:"
  cat "$TMP_JSON"
  exit 1
fi

node - "$CSEBASE_RN" "$TMP_JSON" <<'NODE'
const fs = require('fs');

const rootName = process.argv[2];
const filePath = process.argv[3];

function normalizePath(p) {
  if (!p || typeof p !== 'string') return '';
  return p.replace(/^\/+/, '').replace(/\/+$/, '');
}

function buildTree(paths) {
  const root = { name: rootName, children: new Map() };

  for (const raw of paths) {
    const p = normalizePath(raw);
    if (!p) continue;

    const segs = p.split('/').filter(Boolean);
    if (segs.length === 0) continue;

    let start = 0;
    if (segs[0] === rootName) start = 1;

    let node = root;
    for (let i = start; i < segs.length; i += 1) {
      const s = segs[i];
      if (!node.children.has(s)) {
        node.children.set(s, { name: s, children: new Map() });
      }
      node = node.children.get(s);
    }
  }

  return root;
}

function printNode(node, prefix = '', isLast = true, isRoot = false) {
  if (isRoot) {
    console.log(node.name);
  } else {
    const branch = isLast ? '└── ' : '├── ';
    console.log(prefix + branch + node.name);
  }

  const keys = Array.from(node.children.keys()).sort((a, b) => a.localeCompare(b));
  for (let i = 0; i < keys.length; i += 1) {
    const key = keys[i];
    const child = node.children.get(key);
    const last = i === keys.length - 1;
    const nextPrefix = isRoot ? '' : prefix + (isLast ? '    ' : '│   ');
    printNode(child, nextPrefix, last, false);
  }
}

const payload = JSON.parse(fs.readFileSync(filePath, 'utf8'));
const uriList = payload['m2m:uril'] || payload['m2m:rrl'] || [];

if (!Array.isArray(uriList)) {
  console.error('Unexpected discovery response format.');
  console.error(JSON.stringify(payload, null, 2));
  process.exit(1);
}

const allPaths = new Set(uriList.map(normalizePath));
allPaths.add(normalizePath(rootName));

const tree = buildTree(Array.from(allPaths));
printNode(tree, '', true, true);

console.error(`\nTotal resources (excluding root): ${Math.max(allPaths.size - 1, 0)}`);
NODE
