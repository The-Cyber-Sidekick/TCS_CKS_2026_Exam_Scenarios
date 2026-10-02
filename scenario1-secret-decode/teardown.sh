#!/usr/bin/env bash
# CKS scenario 1 — delete the dedicated kind cluster.
set -euo pipefail
kind delete cluster --name cks-scenario1
