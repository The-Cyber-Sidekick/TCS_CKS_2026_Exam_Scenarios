#!/usr/bin/env bash
# CKS scenario 4 — create the dedicated kind cluster AND arm the scenario.
#
# Arming (modelled on a Pod Security Standards task from the CKS pool; names are this
# lab's own): namespace `edge-tools` has NO Pod Security labels and runs
#   node-inspector  mounts hostPath /var/log/pods (reads every pod's logs on the node)
#   status-page     plain nginx, compliant
#
#   The task:
#     1. Enforce the `baseline` Pod Security Standard on namespace edge-tools.
#     2. Delete the running node-inspector pod.
#     3. Write the event line explaining why it is not recreated to work/pss-denial.log.
#
# Idempotent: rebuilds the namespace unlabelled and removes the answer file.
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER="cks-scenario4"
K="kubectl --context kind-${CLUSTER}"
for cmd in docker kind kubectl; do
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
$K delete namespace edge-tools --ignore-not-found --wait --timeout=120s >/dev/null
rm -rf work && mkdir -p work
$K create namespace edge-tools >/dev/null
$K apply -f manifests/edge-tools.yaml >/dev/null
$K -n edge-tools rollout status deploy/node-inspector --timeout=180s >/dev/null
$K -n edge-tools rollout status deploy/status-page --timeout=180s >/dev/null

echo
echo "✅ Scenario armed."
echo
$K get pods -n edge-tools
echo
echo "🧪 Task:"
echo "   node-inspector mounts the node's /var/log/pods, so it can read every pod's logs."
echo "   1. Enforce the 'baseline' Pod Security Standard on namespace edge-tools."
echo "   2. Delete the running node-inspector pod."
echo "   3. Write the event line that explains why it is not recreated to work/pss-denial.log."
echo
echo "   • ./solution.sh  — apply the answer key and verify"
