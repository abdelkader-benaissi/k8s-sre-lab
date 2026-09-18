#!/usr/bin/env bash
set -euo pipefail
kubectl -n sre-lab run load --labels=access=sre-api --rm -i --restart=Never --image=fortio/fortio:1.69.4 -- load -qps 0 -c 32 -t 5m http://sre-api/
