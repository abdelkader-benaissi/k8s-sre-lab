SHELL := /usr/bin/env bash
.PHONY: cluster bootstrap image deploy validate smoke evidence clean
cluster:
	kind create cluster --config kind.yaml
bootstrap:
	./scripts/bootstrap.sh
image:
	docker build -t ghcr.io/abdelkader-benaissi/k8s-sre-demo:0.1.0 app
	kind load docker-image --name sre-lab ghcr.io/abdelkader-benaissi/k8s-sre-demo:0.1.0
deploy: bootstrap image
	helm upgrade --install sre-demo deploy/chart -n sre-lab --create-namespace --wait
validate:
	helm lint deploy/chart
	helm template sre-demo deploy/chart -n sre-lab | kubectl apply --dry-run=client -f -
	docker run --rm --entrypoint=/bin/promtool -v "$(CURDIR):/work" -w /work prom/prometheus:v3.5.0 check rules deploy/chart/files/slo-rules.yml
	docker run --rm --entrypoint=/bin/promtool -v "$(CURDIR):/work" -w /work prom/prometheus:v3.5.0 test rules observability/rules.test.yml
smoke:
	./scripts/smoke.sh
evidence:
	./scripts/collect-evidence.sh
clean:
	kind delete cluster --name sre-lab
