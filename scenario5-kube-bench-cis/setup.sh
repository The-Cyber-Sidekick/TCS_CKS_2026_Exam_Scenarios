#!/usr/bin/env bash
# CKS scenario 5 — create the two-node kind cluster, install kube-bench on both nodes,
# AND arm the scenario.
#
# Arming (modelled on a CIS benchmark task from the CKS pool; the checks chosen here are
# this lab's own). kube-bench v0.16.0, benchmark cis-1.12, reports three FAILs to fix:
#   control plane  1.4.1  kube-scheduler --profiling is not false (kubeadm default)
#   worker         4.1.9  /var/lib/kubelet/config.yaml is 666 (armed; must be 600)
#   worker         4.2.1  kubelet anonymous auth is enabled   (armed)
#
# Idempotent: removes any --profiling flag from the scheduler and re-arms the worker.
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER="cks-scenario5"
CP="${CLUSTER}-control-plane"
WK="${CLUSTER}-worker"
K="kubectl --context kind-${CLUSTER}"
KB_VER=0.16.0
for cmd in docker kind kubectl curl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "❌ '$cmd' not found in PATH"; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "❌ Docker daemon not running"; exit 1; }

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "✓ Cluster '$CLUSTER' already exists."
else
  echo "▶ Creating kind cluster '$CLUSTER' (control-plane + worker)"
  kind create cluster --config kind-config.yaml
fi
$K wait --for=condition=Ready node --all --timeout=180s >/dev/null

mkdir -p work
[ -s work/kube-bench.deb ] || curl -sSL -o work/kube-bench.deb \
  "https://github.com/aquasecurity/kube-bench/releases/download/v${KB_VER}/kube-bench_${KB_VER}_linux_amd64.deb"
for n in "$CP" "$WK"; do
  docker exec "$n" sh -c 'command -v kube-bench >/dev/null' && continue
  echo "▶ Installing kube-bench on $n"
  docker cp work/kube-bench.deb "$n:/root/kube-bench.deb"   # not /tmp: tmpfs on kind nodes
  docker exec "$n" dpkg -i /root/kube-bench.deb >/dev/null
done
docker exec "$CP" sh -c 'command -v vim >/dev/null || (apt-get update -qq && apt-get install -y -qq vim) >/dev/null 2>&1' || true

echo "▶ Arming the control plane (scheduler without --profiling=false)"
if docker exec "$CP" grep -q -- '--profiling' /etc/kubernetes/manifests/kube-scheduler.yaml; then
  docker exec "$CP" sed -i '/--profiling/d' /etc/kubernetes/manifests/kube-scheduler.yaml
  until ! $K -n kube-system get pod -l component=kube-scheduler -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null | grep -q profiling \
        && $K -n kube-system wait --for=condition=Ready pod -l component=kube-scheduler --timeout=5s >/dev/null 2>&1; do sleep 3; done
fi

echo "▶ Arming the worker (kubelet config 666 + anonymous auth on)"
docker exec "$WK" sh -c "chmod 666 /var/lib/kubelet/config.yaml && \
  sed -i '/^  anonymous:/{n;s/enabled: false/enabled: true/}' /var/lib/kubelet/config.yaml && \
  systemctl restart kubelet"
$K wait --for=condition=Ready node --all --timeout=120s >/dev/null

echo
echo "✅ Scenario armed."
echo
echo "🧪 Task: use kube-bench (installed on both nodes, benchmark cis-1.12) and fix:"
echo "   control plane ($CP):  1.4.1  kube-scheduler --profiling"
echo "   worker ($WK):         4.1.9  kubelet config file permissions"
echo "                                        4.2.1  kubelet anonymous auth"
echo "   docker exec -it <node> bash   (stands in for ssh)"
echo
echo "   • ./solution.sh  — apply the answer key and verify"
