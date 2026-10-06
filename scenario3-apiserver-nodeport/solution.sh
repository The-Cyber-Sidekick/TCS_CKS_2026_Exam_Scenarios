#!/usr/bin/env bash
# CKS scenario 3 — answer key: back up the manifest OUTSIDE the manifests dir, drop the
# --kubernetes-service-node-port flag, wait for the API server to restart, then delete
# the kubernetes Service so it is recreated as ClusterIP. Verify the NodePort is gone.
set -euo pipefail
cd "$(dirname "$0")"
CLUSTER="cks-scenario3"
NODE="${CLUSTER}-control-plane"
K="kubectl --context kind-${CLUSTER}"
MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
docker inspect "$NODE" >/dev/null 2>&1 || { echo "❌ cluster not found — run ./setup.sh first"; exit 1; }
IP="$(docker inspect -f '{{.NetworkSettings.Networks.kind.IPAddress}}' "$NODE")"

echo "▶ 1) Backup (NOT inside /etc/kubernetes/manifests, or the kubelet runs it too)"
docker exec "$NODE" cp "$MANIFEST" /root/kube-apiserver.yaml.bak

echo "▶ 2) Remove the flag"
docker exec "$NODE" sed -i '/--kubernetes-service-node-port/d' "$MANIFEST"

echo "▶ 3) Wait for the API server to come back without it"
until ! $K -n kube-system get pod -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null | grep -q node-port \
      && $K get --raw /readyz >/dev/null 2>&1; do sleep 3; done

echo "▶ 4) Recreate the Service (the API server does not change an existing one's type)"
$K delete svc kubernetes
until $K get svc kubernetes >/dev/null 2>&1; do sleep 2; done
$K get svc kubernetes

# kube-proxy needs a moment to drop the old NodePort rule
for _ in $(seq 30); do
  docker exec "$NODE" curl -sk --max-time 3 "https://${IP}:30443/version" >/dev/null 2>&1 || break; sleep 2
done

echo
TYPE="$($K get svc kubernetes -o jsonpath='{.spec.type}')"
if [ "$TYPE" = "ClusterIP" ] && ! docker exec "$NODE" curl -sk --max-time 5 "https://${IP}:30443/version" >/dev/null 2>&1; then
  echo "✅ Done: kubernetes Service is ClusterIP and nothing answers on ${IP}:30443."
else
  echo "❌ verification failed (type=${TYPE})"; exit 1
fi
