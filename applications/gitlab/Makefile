.PHONY: add-helm-repositories update-dependencies lint package release

CHART_DIR := charts/gitlab
APP_SLUG  := gitlab-pika

add-helm-repositories:
	helm repo add gitlab https://charts.gitlab.io/
	helm repo update

update-dependencies:
	helm dependency update $(CHART_DIR)

lint:
	helm lint $(CHART_DIR)
	helm template gitlab $(CHART_DIR) > /dev/null
	helm template gitlab $(CHART_DIR) -f tests/helm/ci-values.yaml > /dev/null

package: update-dependencies
	helm package $(CHART_DIR)

release: package
	REPLICATED_API_TOKEN=$(REPLICATED_API_TOKEN) replicated release create \
		--app $(APP_SLUG) \
		--chart gitlab-*.tgz \
		--release-notes "Release via Makefile"
