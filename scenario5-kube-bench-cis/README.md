# CKS Lesson 5: Fix CIS benchmark findings with kube-bench

Domain: **Cluster Setup**. Node-side on a two-node kind cluster, `cks-scenario5`
(`docker exec` stands in for `ssh`). `setup.sh` downloads kube-bench v0.16.0 to `work/`
(gitignored) and installs it on both nodes.

## The task

Using kube-bench with benchmark `cis-1.12`, fix:

| Node | Check | Finding |
|---|---|---|
| control plane | 1.4.1 | kube-scheduler `--profiling` not set to false |
| worker | 4.1.9 | `/var/lib/kubelet/config.yaml` permissions (armed at 666; must be 600) |
| worker | 4.2.1 | kubelet anonymous auth enabled (armed) |

The checks are this lab's own choice; exam variants pick different ones.

## Run it

```bash
./setup.sh
docker exec -it cks-scenario5-control-plane bash   # solve it by hand, or:
./solution.sh
./teardown.sh
```

## What it teaches

- `kube-bench run --targets master|node`, per node; `--check <n>` for one remediation.
- Control plane fix = static pod manifest; the kubelet restarts the component itself.
- Kubelet fix = `chmod` / edit `config.yaml`, then `systemctl restart kubelet`.
- Anonymous kubelet auth: no-credential requests become `system:anonymous` (only RBAC
  stops them); disabled, they are `Unauthorized`.
- Fix only what is asked: the worker also fails 4.1.1 under cis-1.12, and we leave it.

## Gotchas (lab)

- kube-bench can't auto-detect the version on the worker (no kubeconfig there) and falls
  back to a 1.18 benchmark, so every run pins `--benchmark cis-1.12`.
- `docker cp` into `/tmp` on a kind node silently fails (tmpfs); the package goes to `/root`.
