#!/usr/bin/env bash
# CKS scenario 1 — create the dedicated kind cluster AND arm the scenario.
#
# Arming = the starting state (modelled on a Secrets task from the CKS pool, domain
# Minimize Microservice Vulnerabilities; every name and value below is this lab's own):
#
#   1. Namespace `finance` holds two Secrets:
#        vault-seed  keys: token (wanted), endpoint (decoy)
#        ops-login   keys: user  (wanted), shell    (decoy)
#   2. Namespace `billing` exists and is empty.
#
#   The task:
#     Part 1. Decode the `token` key of vault-seed and the `user` key of ops-login and
#             write the plain values to work/decoded.txt, one value per line, token first.
#     Part 2. In `billing`, create a Secret `billing-api` with username=svc-invoice and
#             password=Qz7-ledger-2026, then run a pod `invoice-runner` (busybox:1.36)
#             that mounts it read-only at /etc/billing.
#
# Idempotent and re-runnable: rebuilds both namespaces and removes the answer file.
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER="cks-scenario1"
CTX="kind-${CLUSTER}"
K="kubectl --context ${CTX}"

for cmd in docker kind kubectl base64; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "❌ '$cmd' not found in PATH"; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "❌ Docker daemon not running"; exit 1; }

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "✓ Cluster '$CLUSTER' already exists."
else
  echo "▶ Creating kind cluster '$CLUSTER' (single node)"
  kind create cluster --config kind-config.yaml
fi
$K wait --for=condition=Ready node --all --timeout=120s >/dev/null

echo "▶ Resetting to the unsolved state"
$K delete namespace finance billing --ignore-not-found --wait --timeout=120s >/dev/null
rm -rf work && mkdir -p work

echo "▶ Arming the Secrets in ns 'finance' (create, not apply: no last-applied annotation)"
$K create namespace finance >/dev/null
$K create namespace billing >/dev/null
$K -n finance create secret generic vault-seed \
  --from-literal=token=r3d-l4nt3rn-9041 --from-literal=endpoint=https://vault.finance.svc:8200 >/dev/null
$K -n finance create secret generic ops-login \
  --from-literal=user=sre-oncall --from-literal=shell=/bin/bash >/dev/null

echo
echo "✅ Scenario armed."
echo
$K get secrets -n finance
echo
echo "🧪 Task:"
echo "   Part 1. Decode key 'token' of Secret vault-seed and key 'user' of Secret ops-login"
echo "           (both in ns finance). Write the plain values to work/decoded.txt,"
echo "           one per line, token first."
echo "   Part 2. In ns billing, create Secret 'billing-api' (username=svc-invoice,"
echo "           password=Qz7-ledger-2026), then a pod 'invoice-runner' (busybox:1.36)"
echo "           that mounts it READ-ONLY at /etc/billing."
echo
echo "   • ./solution.sh  — apply the answer key and verify"
