# CKS Lesson 4: Enforce the baseline Pod Security Standard on a namespace

Domain: **Minimize Microservice Vulnerabilities**. Host-side `kubectl` on a single-node
kind cluster, `cks-scenario4`.

## The task

In namespace `edge-tools`, Deployment `node-inspector` mounts the node's `/var/log/pods`
through a hostPath volume (it can read every pod's logs on the node).

1. Enforce the `baseline` Pod Security Standard on `edge-tools`.
2. Delete the running `node-inspector` pod.
3. Write the event line explaining why it is not recreated to `work/pss-denial.log`.

Names are this lab's own; exam variants use different ones.

## Run it

```bash
./setup.sh      # solve it by hand, or:
./solution.sh
./teardown.sh
```

## What it teaches

- `kubectl label --dry-run=server --overwrite ns edge-tools pod-security.kubernetes.io/enforce=baseline`
  previews which running pods would violate.
- Enforcement is admission-time only: running pods keep running until deleted.
- The ReplicaSet's `FailedCreate` event carries the reason:
  `kubectl -n edge-tools get events --field-selector reason=FailedCreate`.
- A compliant pod in the same namespace (`status-page`) is unaffected.
