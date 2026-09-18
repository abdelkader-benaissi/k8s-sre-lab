#!/usr/bin/env bash
set -euo pipefail
kubectl -n sre-lab rollout status deployment/sre-api --timeout=2m
kubectl -n sre-lab run smoke --labels=access=sre-api --rm -i --restart=Never --image=curlimages/curl:8.16.0 --fail --silent --show-error http://sre-api/health/ready
