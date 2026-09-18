#!/usr/bin/env bash
set -euo pipefail
kubectl -n sre-lab set image deployment/sre-api api=ghcr.io/abdelkader-benaissi/k8s-sre-demo:does-not-exist
kubectl -n sre-lab rollout status deployment/sre-api --timeout=90s || true
printf '%s\n' 'Recover with: kubectl -n sre-lab rollout undo deployment/sre-api'
