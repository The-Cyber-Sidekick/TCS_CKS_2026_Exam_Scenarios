#!/usr/bin/env bash
# CKS scenario 4 — answer key: preview, then enforce baseline on edge-tools, delete the
# violating pod, and save the ReplicaSet's FailedCreate event to work/pss-denial.log.
set -euo pipefail
cd "$(dirname "$0")"
K="kubectl --context kind-cks-scenario4"
NS=edge-tools
mkdir -p work

echo "▶ 1) Preview: which running pods would violate baseline?"
$K label --dry-run=server --overwrite ns $NS pod-security.kubernetes.io/enforce=baseline

echo "▶ 2) Enforce it"
$K label --overwrite ns $NS pod-security.kubernetes.io/enforce=baseline

echo "▶ 3) Delete the violating pod; the ReplicaSet cannot replace it"
$K -n $NS delete pod -l app=node-inspector --wait
for _ in $(seq 30); do
  $K -n $NS get events --field-selector reason=FailedCreate -o name | grep -q . && break; sleep 2
done

echo "▶ 4) Save the reason"
$K -n $NS get events --field-selector reason=FailedCreate \
  -o custom-columns=REASON:.reason,MESSAGE:.message --no-headers | head -n 1 > work/pss-denial.log
cat work/pss-denial.log
$K -n $NS get pods

echo
LABEL="$($K get ns $NS -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')"
INSP="$($K -n $NS get pods -l app=node-inspector --no-headers 2>/dev/null | wc -l)"
if [ "$LABEL" = "baseline" ] && [ "$INSP" -eq 0 ] && grep -q 'hostPath' work/pss-denial.log \
   && $K -n $NS get pods -l app=status-page --no-headers | grep -q Running; then
  echo "✅ Done: baseline enforced, node-inspector is blocked (hostPath), status-page still runs,"
  echo "   and the denial is saved in work/pss-denial.log."
else
  echo "❌ verification failed (label=${LABEL}, inspector pods=${INSP})"; exit 1
fi
