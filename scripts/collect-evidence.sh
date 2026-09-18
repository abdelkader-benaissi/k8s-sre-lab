#!/usr/bin/env bash
set -euo pipefail
mkdir -p evidence
kubectl -n sre-lab get pods -o wide > evidence/pods.txt
kubectl -n sre-lab get hpa,pdb,endpointslice > evidence/scaling-availability.txt
kubectl -n sre-lab get events --sort-by=.lastTimestamp > evidence/events.txt
kubectl -n sre-lab describe deployment sre-api > evidence/api-deployment.txt
kubectl -n sre-lab get prometheusrule,servicemonitor -o yaml > evidence/observability-resources.yaml
kubectl -n monitoring get pods > evidence/monitoring-pods.txt
kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=2m
kubectl top pods -n sre-lab > evidence/pod-metrics.txt
