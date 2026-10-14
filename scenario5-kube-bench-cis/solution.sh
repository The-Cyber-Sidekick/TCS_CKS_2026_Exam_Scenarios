#!/usr/bin/env bash
# CKS scenario 5 — answer key: fix the three kube-bench findings and re-check each one.
set -euo pipefail
cd "$(dirname "$0")"
CLUSTER="cks-scenario5"
CP="${CLUSTER}-control-plane"
WK="${CLUSTER}-worker"
K="kubectl --context kind-${CLUSTER}"
B="kube-bench run --benchmark cis-1.12"

echo "▶ Control plane 1.4.1: --profiling=false on the scheduler"
docker exec "$CP" sh -c "grep -q -- '--profiling=false' /etc/kubernetes/manifests/kube-scheduler.yaml || \
  sed -i 's|^    - --leader-elect=true|&\n    - --profiling=false|' /etc/kubernetes/manifests/kube-scheduler.yaml"
until $K -n kube-system get pod -l component=kube-scheduler -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null | grep -q profiling \
      && $K -n kube-system wait --for=condition=Ready pod -l component=kube-scheduler --timeout=5s >/dev/null 2>&1; do sleep 3; done

echo "▶ Worker 4.1.9 + 4.2.1: config file 600, anonymous auth off, restart kubelet"
docker exec "$WK" sh -c "chmod 600 /var/lib/kubelet/config.yaml && \
  sed -i '/^  anonymous:/{n;s/enabled: true/enabled: false/}' /var/lib/kubelet/config.yaml && \
  systemctl restart kubelet"
$K wait --for=condition=Ready node --all --timeout=120s >/dev/null

echo
M="$(docker exec "$CP" $B --targets master --check 1.4.1 2>/dev/null | grep -E '^\[(PASS|FAIL)\]')"
N="$(docker exec "$WK" $B --targets node --check 4.1.9,4.2.1 2>/dev/null | grep -E '^\[(PASS|FAIL)\]')"
printf '%s\n%s\n\n' "$M" "$N"
if ! printf '%s\n%s\n' "$M" "$N" | grep -q FAIL && [ "$(printf '%s\n%s\n' "$M" "$N" | grep -c PASS)" -eq 3 ]; then
  echo "✅ Done: 1.4.1, 4.1.9 and 4.2.1 all PASS, and both nodes are Ready."
else
  echo "❌ verification failed"; exit 1
fi
