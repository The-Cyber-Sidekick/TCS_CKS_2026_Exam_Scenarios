# TCS — CKS 2026 Exam Scenarios

Hands-on, self-contained scenarios to help you prepare for the **Certified Kubernetes
Security Specialist (CKS)** exam. Each scenario hands you a cluster set up for one specific,
exam-realistic security task, and you practice solving it under the same conditions you'll
face on the real test.

Every scenario runs on its **own dedicated [kind](https://kind.sigs.k8s.io/) cluster**, so
nothing you change touches anything else on your machine. kind nodes are real kubeadm nodes
(systemd + kubelet + static pods + crictl), so node-side tasks work the way they do on an
exam node — just via `docker exec` instead of SSH.

Object names and task wording are this repo's own; exam variants use different ones.

## 📺 Watch it in action

These scenarios pair with walkthrough videos and writeups:

- **YouTube:** [@thecybersidekick](https://www.youtube.com/@thecybersidekick)
- **dev.to:** [@thecybersidekick](https://dev.to/thecybersidekick)

## Prerequisites

You'll need these on your PATH (the scenarios are built/tested on WSL2):

- [Docker](https://docs.docker.com/get-docker/) (daemon running)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## Scenarios

| # | Scenario | Exam domain | What you practice |
|---|---|---|---|
| 1 | [Decode Kubernetes Secrets, then mount one read-only](scenario1-secret-decode/) | Minimize Microservice Vulnerabilities | Decode two Secret keys into a file, one value per line (minding `base64 -d`'s missing newline), then create a Secret and mount it **read-only** into a pod |
| 2 | [Pull a user's client certificate out of a kubeconfig](scenario2-kubeconfig-cert/) | Cluster Hardening | List a kubeconfig's contexts, then extract and decode one user's client certificate with `--raw` + jsonpath + `base64 -d`, and see why authentication is not authorization |
| 3 | [Stop exposing the API server through a NodePort](scenario3-apiserver-nodeport/) | Cluster Setup | Remove `--kubernetes-service-node-port` from the kube-apiserver static pod (backing it up outside the manifests folder), then delete the `kubernetes` Service so the API server recreates it as ClusterIP-only |

More scenarios coming — each lives in its own directory with a `README.md` and the scripts
to set it up, solve it, and tear it down.

## How a scenario works

```bash
cd scenario1-secret-decode
./setup.sh        # create the dedicated kind cluster and arm the scenario
# ... solve it by hand (each README walks you through it), or:
./solution.sh     # apply the answer key and verify
./teardown.sh     # delete the cluster when you're done
```

## License

See [LICENSE](LICENSE).
