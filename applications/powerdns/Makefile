manifests_dir := $(shell pwd)/manifests
chart_archives := $(wildcard $(manifests_dir)/*.tgz)

ARGS = $(filter-out $@,$(MAKECMDGOALS))
%:
	@:

SHELL := /bin/bash
.SHELLFLAGS = -x +u

# Define the base path to your Helm charts directory
HELM_CHARTS_DIR = ./charts

# Define the path to your target KOTS directory
KOTS_DIR = ./manifests

# Define the function to extract chartVersion
define get_kots_chart_version
	grep 'chartVersion:' $(1) | sed 's/.*chartVersion: //'
endef

# Function to get chart version
define get_helm_chart_version
	helm show chart $(1) | grep '^version:' | cut -d ' ' -f 2
endef

# Target to update chart dependencies
.PHONY: update-chart-dependencies
update-chart-dependencies:
	@for chart in $(HELM_CHARTS_DIR)/*; do \
		echo "Updating dependencies for $$chart"; \
		helm dependency update --skip-refresh $$chart; \
	done

.PHONY: pull-chart-dependencies
pull-chart-dependencies:
	@chart_version=$$(eval $(call get_kots_chart_version,$(KOTS_DIR)/cloudnative-pg-chart.yaml)); \
	helm pull cnpg/cloudnative-pg -d $(KOTS_DIR) --version $$chart_version;

# Target to package charts and update versions
.PHONY: package-and-update
package-and-update: add-helm-repositories pull-chart-dependencies update-chart-dependencies
	@for chart in $(HELM_CHARTS_DIR)/*; do \
			echo "Packaging $$chart"; \
			helm package $$chart -d $(KOTS_DIR); \
			version=$$(eval $(call get_helm_chart_version,$$chart)); \
		chart_name=$$(basename $$chart); \
			echo "Updating version to $$version in $(KOTS_DIR)/*-chart.yaml"; \
			sed -i '' 's|chartVersion: [0-9a-zA-Z.-]*|chartVersion: '$$version'|g' $(KOTS_DIR)/$$chart_name-chart.yaml; \
	done

# Target to add Helm repositories
.PHONY: add-helm-repositories
add-helm-repositories:
	@helm repo add cnpg https://cloudnative-pg.github.io/charts

# Example target to check versions (optional)
.PHONY: check-versions
check-versions:
	@for chart_dir in $(HELM_CHARTS_DIR)/*; do \
			if [ -d $$chart_dir ]; then \
					version=$$(eval $(call get_helm_chart_version,$$chart_dir)); \
					echo "$$chart_dir version: $$version"; \
			fi \
	done

.PHONY: clean
clean: clean-charts

.PHONY: clean-charts
clean-charts:
	rm -f $(KOTS_DIR)/*.tgz $(HELM_CHARTS_DIR)/*/charts/*.tgz

.PHONY: release
release: clean-charts package-and-update
	replicated release create --auto -y --promote Unstable
