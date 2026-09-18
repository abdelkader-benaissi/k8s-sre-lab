#!/usr/bin/env bash
set -euo pipefail

HELM=${HELM:-helm}
CILIUM_VERSION=${CILIUM_VERSION:-1.18.2}
METRICS_SERVER_VERSION=${METRICS_SERVER_VERSION:-3.13.0}
PROMETHEUS_STACK_VERSION=${PROMETHEUS_STACK_VERSION:-77.11.1}

for command_name in kubectl "$HELM"; do
  command -v "$command_name" >/dev/null || { printf 'missing required command: %s\n' "$command_name" >&2; exit 1; }
done

$HELM repo add cilium https://helm.cilium.io/
$HELM repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
$HELM repo add prometheus-community https://prometheus-community.github.io/helm-charts
$HELM repo update

$HELM upgrade --install cilium cilium/cilium -n kube-system --version "$CILIUM_VERSION" \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=sre-lab-control-plane \
  --set k8sServicePort=6443 \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true
kubectl rollout status -n kube-system ds/cilium --timeout=5m

$HELM upgrade --install metrics-server metrics-server/metrics-server -n kube-system \
  --version "$METRICS_SERVER_VERSION" --set 'args={--kubelet-insecure-tls}'
$HELM upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace \
  --version "$PROMETHEUS_STACK_VERSION" --set grafana.adminPassword=local-lab-only
kubectl rollout status -n monitoring deployment/monitoring-kube-prometheus-operator --timeout=5m
kubectl create namespace sre-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace sre-lab pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted pod-security.kubernetes.io/warn=restricted --overwrite
