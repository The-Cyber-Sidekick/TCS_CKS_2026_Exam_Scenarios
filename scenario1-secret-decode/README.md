# CKS Lesson 1: Decode Kubernetes Secrets, then mount one read-only

Domain: **Minimize Microservice Vulnerabilities**. Host-side `kubectl` on a dedicated
single-node kind cluster, `cks-scenario1`.

## The task

**Part 1.** Namespace `finance` holds two Secrets, each with two keys. Decode key `token` of
`vault-seed` and key `user` of `ops-login`, and write the plain values to `work/decoded.txt`,
one value per line, token first.

**Part 2.** In namespace `billing`, create a Secret `billing-api` with
`username=svc-invoice` and `password=Qz7-ledger-2026`, then run a pod `invoice-runner`
(`busybox:1.36`) that mounts it **read-only** at `/etc/billing`.

Object names and values are this lab's own; exam variants use different ones.

## Run it

```bash
./setup.sh        # create the cluster and arm the scenario (re-runnable)
# solve it by hand, or:
./solution.sh     # answer key + verification
./teardown.sh     # delete the cluster
```

## What it teaches

- Secret `data` is base64: an **encoding, not encryption**. `get` on a Secret = read access.
- `kubectl get secret X -o jsonpath='{.data.KEY}' | base64 -d` decodes one key.
- `base64 -d` prints no trailing newline, so add one per value when building the file;
  check with `cat -A` (each line ends in `$`).
- `echo -n` when encoding by hand; plain `echo` puts a newline inside the value and changes
  the base64 (the demo shows both).
- `kubectl create secret generic --from-literal` encodes for you.
- `readOnly: true` on the volumeMount. The kubelet mounts secret volumes read-only anyway,
  but graders check the spec, so set it explicitly.

## Answer key

`manifests/invoice-runner.yaml` is the part 2 pod. The answer file lives in `work/`
(gitignored, recreated by `setup.sh`).
