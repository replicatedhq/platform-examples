manifests_dir := $(shell pwd)/kots
chart_archives := $(wildcard $(manifests_dir)/*.tgz)

ARGS = $(filter-out $@,$(MAKECMDGOALS))
%:
	@:

SHELL := /bin/bash
.SHELLFLAGS = -x +u

# Define the base path to your Helm charts directory
HELM_CHARTS_DIR = ./charts

# Define the path to your target KOTS directory
KOTS_DIR = ./kots

# Define the function to extract chartVersion
define get_kots_chart_version
	grep 'chartVersion:' $(1) | sed 's/.*chartVersion: //'
endef

# Function to get chart version
define get_helm_chart_version
    helm show chart $(1) | grep '^version:' | cut -d ' ' -f 2
endef

# Target to package charts and update versions
.PHONY: package-and-update
package-and-update: add-helm-repositories
	@for chart in $(HELM_CHARTS_DIR)/*; do \
	    echo "Packaging $$chart"; \
	    helm package $$chart -u -d $(KOTS_DIR); \
	    version=$$(eval $(call get_helm_chart_version,$$chart)); \
		chart_name=$$(basename $$chart); \
	    echo "Updating version to $$version in $(KOTS_DIR)/*-chart.yaml"; \
	    sed -i '' 's|chartVersion: [0-9a-zA-Z.-]*|chartVersion: '$$version'|g' $(KOTS_DIR)/$$chart_name-chart.yaml; \
	done

