#!/usr/bin/env bash
set -euo pipefail
kubectl -n sre-lab run error-load --labels=access=sre-api --rm -i --restart=Never --image=fortio/fortio:1.69.4 -- load -qps 5 -c 4 -t 10m 'http://sre-api/?fail=true'
