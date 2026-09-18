#!/usr/bin/env bash
set -euo pipefail
node=${1:?usage: drain-worker.sh NODE}
[[ $(kubectl config current-context) == kind-sre-lab ]] || { printf '%s\n' 'refusing to drain outside kind-sre-lab' >&2; exit 1; }
[[ $node == sre-lab-worker* ]] || { printf '%s\n' 'refusing to drain a non-lab worker' >&2; exit 1; }
kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data
printf 'Recover with: kubectl uncordon %q\n' "$node"
