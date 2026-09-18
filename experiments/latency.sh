#!/usr/bin/env bash
set -euo pipefail
kubectl -n sre-lab run latency-load --labels=access=sre-api --rm -i --restart=Never --image=fortio/fortio:1.69.4 -- load -qps 10 -c 4 -t 5m 'http://sre-api/?delay=750ms'
