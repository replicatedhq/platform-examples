SHELL := /bin/bash
.SHELLFLAGS = -eu -o pipefail -c

KOTS_DIR := ./kots
CHARTS_DIR := ./charts
AKKOMA_CHART_REPO := https://github.com/adamancini/akkoma-helm.git
AKKOMA_CHART_BRANCH ?= main
AKKOMA_CHART_DIR := $(CHARTS_DIR)/akkoma-helm/charts/akkoma
AKKOMA_CHART_YAML := $(AKKOMA_CHART_DIR)/Chart.yaml

.PHONY: clone-chart
clone-chart: ## Clone or update the akkoma-helm chart repository
	@if [ -d "$(CHARTS_DIR)/akkoma-helm" ]; then \
		echo "Updating existing akkoma-helm clone..."; \
		cd $(CHARTS_DIR)/akkoma-helm && git fetch origin && git checkout $(AKKOMA_CHART_BRANCH) && git pull origin $(AKKOMA_CHART_BRANCH); \
	else \
		echo "Cloning akkoma-helm repository..."; \
		mkdir -p $(CHARTS_DIR); \
		git clone --branch $(AKKOMA_CHART_BRANCH) $(AKKOMA_CHART_REPO) $(CHARTS_DIR)/akkoma-helm; \
	fi

.PHONY: update-dependencies
update-dependencies: clone-chart ## Update Helm chart dependencies
	@echo "Updating dependencies for $(AKKOMA_CHART_DIR)"
	@helm dependency update $(AKKOMA_CHART_DIR)

.PHONY: package-and-update
package-and-update: clean clone-chart update-dependencies ## Package chart and update version in KOTS manifests
	@echo "Packaging $(AKKOMA_CHART_DIR)"
	@helm package $(AKKOMA_CHART_DIR) -d $(KOTS_DIR)
	@version=$$(grep '^version:' $(AKKOMA_CHART_YAML) | cut -d ' ' -f 2); \
	echo "Updating chartVersion to $$version in $(KOTS_DIR)/akkoma-chart.yaml"; \
	sed -i.bak "s|chartVersion: [0-9a-zA-Z.-]*|chartVersion: $$version|g" $(KOTS_DIR)/akkoma-chart.yaml && rm -f $(KOTS_DIR)/akkoma-chart.yaml.bak

.PHONY: clean
clean: ## Remove build artifacts
	@echo "Cleaning up build artifacts in $(KOTS_DIR)"
	@rm -f $(KOTS_DIR)/*.tgz
	@echo "Removing cloned chart directory"
	@rm -rf $(CHARTS_DIR)

.PHONY: release
release: package-and-update ## Package and create a Replicated release on the Unstable channel
	@version=$$(grep '^version:' $(AKKOMA_CHART_YAML) | cut -d ' ' -f 2); \
	echo "Creating release version $$version on Unstable channel"; \
	replicated release create --yaml-dir $(KOTS_DIR) --promote Unstable --version "$$version"

.PHONY: lint
lint: clone-chart update-dependencies ## Lint Helm chart and KOTS manifests
	@echo "Linting Helm chart..."
	@helm lint $(AKKOMA_CHART_DIR)
	@echo ""
	@echo "Linting KOTS manifests..."
	@helm package $(AKKOMA_CHART_DIR) -d $(KOTS_DIR) >/dev/null 2>&1
	@replicated release lint --yaml-dir $(KOTS_DIR)
	@rm -f $(KOTS_DIR)/*.tgz

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
