# CKS Lesson 3: Stop exposing the API server through a NodePort

Domain: **Cluster Setup**. Node-side (`docker exec` into the control plane, like SSH in
the exam) on a single-node kind cluster, `cks-scenario3`.

## The task

A security review found the API server reachable through a NodePort. Change the setup so
it is reachable through a ClusterIP Service only.

`setup.sh` arms it by adding `--kubernetes-service-node-port=30443` to the kube-apiserver
static pod and recreating the `kubernetes` Service. Values are this lab's own.

## Run it

```bash
./setup.sh
docker exec -it cks-scenario3-control-plane bash   # solve it by hand, or:
./solution.sh
./teardown.sh
```

## What it teaches

- The `default/kubernetes` Service is created and maintained by the API server.
- `--kubernetes-service-node-port` opens the API server on every node; anonymous `/version`
  already leaks the exact build.
- Back up `/etc/kubernetes/manifests/kube-apiserver.yaml` **outside** the manifests folder.
- The API server only sets the type on **create**: after removing the flag, the Service is
  still a NodePort until you `kubectl delete svc kubernetes` (it is recreated as ClusterIP).
- kube-proxy takes a moment to close the port; the scripts poll before checking.
