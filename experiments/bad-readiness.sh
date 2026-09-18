#!/usr/bin/env bash
set -euo pipefail
kubectl -n sre-lab patch deployment sre-api --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/does-not-exist"}]'
printf '%s\n' 'Recover with: kubectl -n sre-lab rollout undo deployment/sre-api'
