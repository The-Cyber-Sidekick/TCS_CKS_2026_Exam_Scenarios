#!/usr/bin/env bash
# CKS scenario 1 — answer key. Decode two Secret keys into work/decoded.txt (one per
# line), then create billing-api in ns billing and mount it read-only into invoice-runner.
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER="cks-scenario1"
CTX="kind-${CLUSTER}"
K="kubectl --context ${CTX}"
docker inspect "${CLUSTER}-control-plane" >/dev/null 2>&1 || { echo "❌ cluster not found — run ./setup.sh first"; exit 1; }
mkdir -p work

echo "▶ Part 1: decode the two keys, one value per line"
{
  $K -n finance get secret vault-seed -o jsonpath='{.data.token}' | base64 -d; echo
  $K -n finance get secret ops-login  -o jsonpath='{.data.user}'  | base64 -d; echo
} > work/decoded.txt
cat work/decoded.txt

echo
echo "▶ Part 2: create the Secret and the pod that mounts it read-only"
$K -n billing delete pod invoice-runner --ignore-not-found --wait >/dev/null
$K -n billing delete secret billing-api --ignore-not-found >/dev/null
$K -n billing create secret generic billing-api \
  --from-literal=username=svc-invoice --from-literal=password=Qz7-ledger-2026
$K apply -f manifests/invoice-runner.yaml
$K -n billing wait --for=condition=Ready pod/invoice-runner --timeout=120s
$K -n billing exec invoice-runner -- cat /etc/billing/username; echo

echo
EXPECT=$'r3d-l4nt3rn-9041\nsre-oncall'
GOT="$(cat work/decoded.txt)"
PW="$($K -n billing exec invoice-runner -- cat /etc/billing/password)"
RO="$($K -n billing get pod invoice-runner -o jsonpath='{.spec.containers[0].volumeMounts[0].readOnly}')"
if [ "$GOT" = "$EXPECT" ] && [ "$(wc -l < work/decoded.txt)" -eq 2 ] \
   && [ "$PW" = "Qz7-ledger-2026" ] && [ "$RO" = "true" ]; then
  echo "✅ Done: decoded.txt has both values on their own lines, and invoice-runner"
  echo "   reads billing-api from a read-only mount at /etc/billing."
else
  echo "❌ verification failed (decoded='${GOT//$'\n'/|}', password='${PW}', readOnly='${RO}')"; exit 1
fi
