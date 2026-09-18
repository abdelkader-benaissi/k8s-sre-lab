#!/usr/bin/env bash
set -euo pipefail
kubectl -n sre-lab patch deployment sre-api --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"16Mi"},{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"32Mi"},{"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{"name":"ALLOCATE_MB","value":"96"}}]'
kubectl -n sre-lab rollout status deployment/sre-api --timeout=90s || true
kubectl -n sre-lab get pods -l app=sre-api -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}{end}'
printf '%s\n' 'Recover with: helm upgrade --install sre-demo deploy/chart -n sre-lab'
