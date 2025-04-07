REPLICATED_APP=gerard-helm-fake-service
REPLICATED_DIR=$(shell pwd)/replicated
CHART_DIR=$(shell pwd)/app
CHART_VERSION=0.8.0
CHANNELS=Stable Unstable Beta

clean-charts:
	rm -rf $(REPLICATED_DIR)/*.tgz

bump-chart-version:
	yq -i '.version = "$(CHART_VERSION)"' $(CHART_DIR)/Chart.yaml
	yq -i '.spec.chart.chartVersion = "$(CHART_VERSION)"' $(REPLICATED_DIR)/kots-chart.yaml

helm-dep-up:
	helm dep up $(CHART_DIR)

helm-dep-list:
	helm dep list $(CHART_DIR)

helm-install-dry-run:
	helm install $(REPLICATED_APP) --dry-run --debug $(CHART_DIR)

helm-template:
	helm template $(REPLICATED_APP) $(CHART_DIR)

helm-template-with-values:
	yq '.spec.values' replicated/kots-sample-config-values.yaml | helm template $(REPLICATED_APP) --values - $(CHART_DIR)

helm-install:
	helm install $(REPLICATED_APP) --debug --wait $(CHART_DIR)

helm-uninstall:
	helm uninstall $(REPLICATED_APP)

prepare-release: clean-charts helm-dep-up bump-chart-version
	helm package --destination $(REPLICATED_DIR) --debug ./app
	echo "Packaged Helm chart to $(REPLICATED_DIR)"

replicated-lint:
	replicated release lint --yaml-dir $(REPLICATED_DIR)

replicated-release: prepare-release replicated-lint
	replicated release create --yaml-dir $(REPLICATED_DIR)

replicated-promote:
	$(eval SEQUENCE := $(shell replicated release ls --output json | jq '.[0].sequence'))
	@for channel in $(CHANNELS); do \
		echo "Promoting release sequence $(SEQUENCE) to $$channel channel..."; \
		replicated release promote $(SEQUENCE) $$channel; \
	done

sync-platform-examples:
	rsync -av --exclude '.git' --exclude '.gitignore' . /Users/gerard/dev/platform-examples/applications/fake-services/