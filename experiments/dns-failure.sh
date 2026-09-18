#!/usr/bin/env bash
set -euo pipefail
kubectl -n sre-lab set env deployment/sre-api REDIS_URL=redis://does-not-exist.sre-lab.svc:6379/0
kubectl -n sre-lab rollout status deployment/sre-api --timeout=90s || true
printf '%s\n' 'Recover with: kubectl -n sre-lab rollout undo deployment/sre-api'
