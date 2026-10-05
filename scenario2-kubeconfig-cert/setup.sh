#!/usr/bin/env bash
# CKS scenario 2 — create the dedicated kind cluster AND arm the scenario.
#
# Arming (modelled on a kubeconfig task from the CKS pool; every name is this lab's own):
#   work/kubeconfig is the "workstation" kubeconfig. It holds four contexts:
#     kind-cks-scenario2       cluster admin (the real lab cluster)
#     auditor@payments-stage   user auditor, a REAL client certificate issued by this
#                              cluster's CSR API (CN=auditor, O=payments-auditors)
#     ops@payments-prod        placeholder cluster, never contacted
#     ci@build-farm            placeholder cluster, never contacted
#
#   The task:
#     1. Write every context name in the kubeconfig to work/contexts.txt, one per line.
#     2. Write the DECODED client certificate of user auditor@payments-stage to
#        work/auditor.crt.
#
# The lab never touches ~/.kube/config: every command uses KUBECONFIG=work/kubeconfig.
# Idempotent: rebuilds work/ and re-issues the certificate on every run.
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER="cks-scenario2"
for cmd in docker kind kubectl openssl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "❌ '$cmd' not found in PATH"; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "❌ Docker daemon not running"; exit 1; }

rm -rf work && mkdir -p work
export KUBECONFIG="$PWD/work/kubeconfig"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "✓ Cluster '$CLUSTER' already exists."
else
  echo "▶ Creating kind cluster '$CLUSTER' (single node)"
  kind create cluster --config kind-config.yaml --kubeconfig "$KUBECONFIG"
fi
kind export kubeconfig --name "$CLUSTER" --kubeconfig "$KUBECONFIG" >/dev/null 2>&1
kubectl wait --for=condition=Ready node --all --timeout=120s >/dev/null

echo "▶ Issuing a real client certificate for 'auditor' through the CSR API"
openssl genrsa -out work/auditor.key 2048 2>/dev/null
openssl req -new -key work/auditor.key -subj "/CN=auditor/O=payments-auditors" -out work/auditor.csr 2>/dev/null
kubectl delete csr auditor-csr --ignore-not-found >/dev/null
cat <<CSR | kubectl apply -f - >/dev/null
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: auditor-csr
spec:
  request: $(base64 -w0 < work/auditor.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 2592000
  usages: ["client auth"]
CSR
kubectl certificate approve auditor-csr >/dev/null
for _ in $(seq 30); do
  CERT="$(kubectl get csr auditor-csr -o jsonpath='{.status.certificate}')"
  [ -n "$CERT" ] && break; sleep 1
done
[ -n "$CERT" ] || { echo "❌ CSR was not signed"; exit 1; }
echo "$CERT" | base64 -d > work/issued.crt

echo "▶ Building the four-context workstation kubeconfig"
SERVER="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
kubectl config set-cluster payments-stage --server="$SERVER" --embed-certs \
  --certificate-authority=<(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d) >/dev/null
kubectl config set-credentials auditor@payments-stage --embed-certs \
  --client-certificate=work/issued.crt --client-key=work/auditor.key >/dev/null
kubectl config set-context auditor@payments-stage --cluster=payments-stage --user=auditor@payments-stage >/dev/null
kubectl config set-cluster payments-prod --server=https://10.40.0.10:6443 >/dev/null
kubectl config set-credentials ops@payments-prod --token=placeholder-not-a-real-token >/dev/null
kubectl config set-context ops@payments-prod --cluster=payments-prod --user=ops@payments-prod >/dev/null
kubectl config set-cluster build-farm --server=https://10.60.0.10:6443 >/dev/null
kubectl config set-credentials ci@build-farm --token=placeholder-not-a-real-token >/dev/null
kubectl config set-context ci@build-farm --cluster=build-farm --user=ci@build-farm >/dev/null
kubectl config use-context kind-cks-scenario2 >/dev/null
rm -f work/issued.crt work/auditor.key work/auditor.csr   # only the kubeconfig holds it now

echo
echo "✅ Scenario armed. Use:  export KUBECONFIG=$PWD/work/kubeconfig"
echo
kubectl config get-contexts
echo
echo "🧪 Task:"
echo "   1. Write every context name to work/contexts.txt, one per line."
echo "   2. Write the DECODED client certificate of user 'auditor@payments-stage'"
echo "      to work/auditor.crt."
echo
echo "   • ./solution.sh  — apply the answer key and verify"
