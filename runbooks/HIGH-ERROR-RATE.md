# High error rate

1. Confirm user impact with the availability and latency SLI, not Pod count alone.
2. Record alert start, deploy revision, affected routes, regions/nodes, and error-budget burn.
3. Compare application errors with dependency saturation, restarts, EndpointSlices, and recent events.
4. If correlated with a rollout, pause and roll back. If dependency saturation is causal, shed load or scale within tested limits.
5. Validate recovery using request success rate and latency for at least one complete alert window.
6. Preserve query output, Kubernetes events, relevant logs, and the corrective commit.

Do not restart everything before collecting evidence; that destroys state and usually delays diagnosis.
