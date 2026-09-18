# Pod Pending

Inspect in this order: scheduler events; requests versus allocatable capacity; taints/tolerations; node affinity; topology constraints; PVC binding; quotas; then admission policy. A Pending Pod has not started, so application logs are usually irrelevant.
