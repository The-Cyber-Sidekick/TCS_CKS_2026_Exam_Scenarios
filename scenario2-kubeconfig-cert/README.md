# CKS Lesson 2: Pull a user's client certificate out of a kubeconfig

Domain: **Cluster Hardening**. Host-side `kubectl` + `openssl` on a single-node kind
cluster, `cks-scenario2`. The lab uses its own kubeconfig (`work/kubeconfig`) and never
touches `~/.kube/config`.

## The task

The kubeconfig at `work/kubeconfig` has four contexts.

1. Write every context name to `work/contexts.txt`, one per line.
2. Write the **decoded** client certificate of user `auditor@payments-stage` to
   `work/auditor.crt`.

The auditor's certificate is real: `setup.sh` issues it through the cluster's CSR API
(CN=auditor, O=payments-auditors). Names are this lab's own; exam variants use different ones.

## Run it

```bash
./setup.sh                               # create the cluster, build work/kubeconfig
export KUBECONFIG=$PWD/work/kubeconfig   # solve it by hand, or:
./solution.sh                            # answer key + verification
./teardown.sh
```

## What it teaches

- `kubectl config get-contexts -o name` = names only, one per line.
- `kubectl config view` redacts credentials as `DATA+OMITTED`; `--raw` shows them.
- `-o jsonpath='{.users[?(@.name=="auditor@payments-stage")].user.client-certificate-data}' | base64 -d`
- `openssl x509 -noout -subject`: CN is the username, O is the group RBAC sees.
- `auth whoami` succeeds but `get pods` is Forbidden: authentication is not authorization.
