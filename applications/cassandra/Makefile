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
package-and-update: clean add-helm-repositories update-dependencies
	@for chart in $(HELM_CHARTS_DIR)/*; do \
	    echo "Packaging $$chart"; \
	    helm package $$chart -u -d $(KOTS_DIR); \
	    version=$$(eval $(call get_helm_chart_version,$$chart)); \
		chart_name=$$(basename $$chart); \
	    echo "Updating version to $$version in $(KOTS_DIR)/*-chart.yaml"; \
	    sed -i '' 's|chartVersion: [0-9a-zA-Z.-]*|chartVersion: '$$version'|g' $(KOTS_DIR)/$$chart_name-chart.yaml; \
	done


.PHONY: clean
clean:
	@echo "Cleaning up build artifacts in $(KOTS_DIR)"
	@rm -f $(KOTS_DIR)/*.tgz


.PHONY: update-dependencies
update-dependencies:
	@for chart_dir in $(HELM_CHARTS_DIR)/*; do \
	    if [ -d $$chart_dir ]; then \
	        echo "Updating dependencies for $$chart_dir"; \
	        helm dependency update $$chart_dir; \
	    fi; \
	done


# Target to add Helm repositories from Chart.yaml files
.PHONY: add-helm-repositories
add-helm-repositories:
	@for chart_file in $(HELM_CHARTS_DIR)/*/Chart.yaml; do \
	    echo "Processing $$chart_file"; \
	    repo_name=$$(grep '^name:' $$chart_file | awk '{print $$2}'); \
	    grep 'dependencies:' -A 10 $$chart_file | grep 'repository:' | awk '{print $$2}' | while read repo; do \
	        if ! helm repo list | grep -q "^$$repo_name[[:space:]]"; then \
	            echo "Adding Helm repo $$repo_name from $$repo"; \
	            helm repo add $$repo_name $$repo || true; \
	        fi; \
	    done; \
	done
	@helm repo update


.PHONY: release
release: package-and-update
	@echo "Creating a new release with Replicated"
	@replicated release create --yaml-dir $(KOTS_DIR) --promote Unstable
