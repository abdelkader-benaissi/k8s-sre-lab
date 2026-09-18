#!/usr/bin/env bash
set -euo pipefail
kubectl -n sre-lab rollout status deployment/sre-api --timeout=2m
kubectl -n sre-lab delete pod smoke --ignore-not-found --wait=true >/dev/null
trap 'kubectl -n sre-lab delete pod smoke --ignore-not-found --wait=false >/dev/null' EXIT

kubectl -n sre-lab apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: smoke
  labels: {access: sre-api}
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    seccompProfile: {type: RuntimeDefault}
  containers:
    - name: curl
      image: curlimages/curl:8.16.0
      command: [curl, --fail, --silent, --show-error, --max-time, "20", http://sre-api/health/ready]
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities: {drop: [ALL]}
YAML

if ! kubectl -n sre-lab wait --for=jsonpath='{.status.phase}'=Succeeded pod/smoke --timeout=2m; then
  kubectl -n sre-lab describe pod smoke || true
  kubectl -n sre-lab logs pod/smoke || true
  exit 1
fi
kubectl -n sre-lab logs pod/smoke
