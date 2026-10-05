#!/usr/bin/env bash
# CKS scenario 2 — answer key: list the contexts into a file, extract the auditor's
# client certificate decoded, then prove what it is and that it authenticates.
set -euo pipefail
cd "$(dirname "$0")"
export KUBECONFIG="$PWD/work/kubeconfig"
[ -f "$KUBECONFIG" ] || { echo "❌ work/kubeconfig missing — run ./setup.sh first"; exit 1; }

echo "▶ 1) Context names, one per line"
kubectl config get-contexts -o name > work/contexts.txt
cat work/contexts.txt

echo
echo "▶ 2) The auditor's client certificate, decoded"
kubectl config view --raw \
  -o jsonpath='{.users[?(@.name=="auditor@payments-stage")].user.client-certificate-data}' \
  | base64 -d > work/auditor.crt
head -n 1 work/auditor.crt
openssl x509 -in work/auditor.crt -noout -subject -issuer -enddate

echo
echo "▶ 3) It really is a working identity on this cluster"
kubectl --context auditor@payments-stage auth whoami

echo
N="$(wc -l < work/contexts.txt)"
SUBJ="$(openssl x509 -in work/auditor.crt -noout -subject)"
if [ "$N" -eq 4 ] && grep -qx 'auditor@payments-stage' work/contexts.txt \
   && [[ "$SUBJ" == *"CN=auditor"* ]] && [[ "$SUBJ" == *"O=payments-auditors"* ]]; then
  echo "✅ Done: 4 context names written, and auditor.crt is the decoded PEM certificate"
  echo "   for CN=auditor, O=payments-auditors."
else
  echo "❌ verification failed (contexts=${N}, subject='${SUBJ}')"; exit 1
fi
