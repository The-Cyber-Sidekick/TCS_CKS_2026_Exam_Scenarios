#!/usr/bin/env bash
# CKS scenario 3 — create the dedicated kind cluster AND arm the scenario.
#
# Arming (modelled on an API-server exposure task from the CKS pool; values are this
# lab's own): the kube-apiserver static pod runs with
#     --kubernetes-service-node-port=30443
# so the default/kubernetes Service is a NodePort, and the API server answers on
# <node-ip>:30443 from anywhere that can reach the node.
#
#   The task: a security review flagged that the API server is reachable through a
#   NodePort. Change the setup so it is reachable through a ClusterIP Service only.
#
# Idempotent: re-applies the flag, waits for the API server to restart with it, and
# recreates the Service so it comes back as a NodePort.
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER="cks-scenario3"
NODE="${CLUSTER}-control-plane"
K="kubectl --context kind-${CLUSTER}"
MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml

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

# kind nodes ship without an editor; the task is a manifest edit (best effort)
docker exec "$NODE" sh -c 'command -v vim >/dev/null || (apt-get update -qq && apt-get install -y -qq vim) >/dev/null 2>&1' || true

apiserver_cmd() { $K -n kube-system get pod -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null; }

echo "▶ Arming: kube-apiserver --kubernetes-service-node-port=30443"
docker exec "$NODE" sh -c "sed -i '/--kubernetes-service-node-port/d' $MANIFEST && \
  sed -i 's|^    - --advertise-address=.*|&\n    - --kubernetes-service-node-port=30443|' $MANIFEST"
until apiserver_cmd | grep -q 'node-port=30443' && $K get --raw /readyz >/dev/null 2>&1; do sleep 3; done

# the API server only sets the type when it CREATES the Service, so recreate it
$K delete svc kubernetes >/dev/null
until $K get svc kubernetes -o jsonpath='{.spec.type}' 2>/dev/null | grep -qx NodePort; do sleep 2; done

echo
echo "✅ Scenario armed."
echo
$K get svc kubernetes
echo
echo "🧪 Task: the API server is reachable through a NodePort. Make it reachable"
echo "   through a ClusterIP Service only. (docker exec -it ${NODE} bash)"
echo
echo "   • ./solution.sh  — apply the answer key and verify"
