manifests_dir := $(shell pwd)/kots
chart_archives := $(wildcard $(manifests_dir)/*.tgz)

ARGS = $(filter-out $@,$(MAKECMDGOALS))
%:
	@:

SHELL := /bin/bash
.SHELLFLAGS = -x +u -c

# Define the base path to your Helm charts directory
HELM_CHARTS_DIR = ./charts

# Define the path to your target KOTS directory
KOTS_DIR = ./kots

# Path to Gitea's Chart.yaml
GITEA_CHART_PATH = ./charts/gitea/Chart.yaml

# Function to extract version from Chart.yaml
define get_gitea_chart_version
	cat $(GITEA_CHART_PATH) | grep '^version:' | cut -d ' ' -f 2
endef


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
package-and-update: clean
	@for chart in $(HELM_CHARTS_DIR)/*; do \
	    echo "Packaging $$chart"; \
	    helm package $$chart -d $(KOTS_DIR); \
	    version=$$(eval $(call get_helm_chart_version,$$chart)); \
		chart_name=$$(basename $$chart); \
	    echo "Updating version to $$version in $(KOTS_DIR)/*-chart.yaml"; \
	    sed -i.bak 's|chartVersion: [0-9a-zA-Z.-]*|chartVersion: '$$version'|g' $(KOTS_DIR)/$$chart_name-chart.yaml && rm -f $(KOTS_DIR)/$$chart_name-chart.yaml.bak; \
	done


.PHONY: clean
clean:
	@echo "Cleaning up build artifacts in $(KOTS_DIR)"
	@rm -f $(KOTS_DIR)/*.tgz
	@echo "Removing old Helm tmpcharts-* directories"
	@rm -rf $(HELM_CHARTS_DIR)/*/tmpcharts-*


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
	    grep 'dependencies:' -A 10 $$chart_file | grep 'repository:' | awk '{print $$2}' | tr -d '"' | while read repo; do \
	        if ! helm repo list | grep -q "^$$repo_name[[:space:]]"; then \
	            echo "Adding Helm repo $$repo_name from $$repo"; \
	            helm repo add $$repo_name $$repo || true; \
	        fi; \
	    done; \
	done
	@helm repo update


.PHONY: release
release: package-and-update
	@chart_version=$$(eval $(call get_gitea_chart_version)); \
	echo "Creating a new release with Replicated using version $$chart_version"; \
	replicated release create --yaml-dir $(KOTS_DIR) --promote Unstable --version "$$chart_version"


# ---------------------------------------------------------------------------
# Test targets
# ---------------------------------------------------------------------------

CI_VALUES = tests/helm/ci-values.yaml
RELEASE_NAME = gitea
NAMESPACE = default

.PHONY: test-lint
test-lint: add-helm-repositories update-dependencies
	helm lint ./charts/gitea
	helm template $(RELEASE_NAME) ./charts/gitea > /dev/null
	helm template $(RELEASE_NAME) ./charts/gitea -f $(CI_VALUES) > /dev/null

.PHONY: test-install-operators
test-install-operators:
	helm repo add jetstack https://charts.jetstack.io || true
	helm repo add cnpg https://cloudnative-pg.github.io/charts || true
	helm repo update jetstack cnpg
	helm install cert-manager jetstack/cert-manager \
		--namespace cert-manager --create-namespace \
		--set crds.enabled=true \
		--wait --timeout 5m
	helm install cnpg cnpg/cloudnative-pg \
		--namespace cnpg-system --create-namespace \
		--wait --timeout 5m

.PHONY: test-install
test-install: add-helm-repositories update-dependencies
	helm install $(RELEASE_NAME) ./charts/gitea \
		-f $(CI_VALUES) \
		--namespace $(NAMESPACE) \
		--wait --timeout 10m

.PHONY: test-smoke
test-smoke:
	python3 -m venv ./venv
	./venv/bin/pip install -r tests/requirements.txt
	./venv/bin/python tests/smoke_test.py \
		--release $(RELEASE_NAME) --namespace $(NAMESPACE)

.PHONY: test-all
test-all: test-lint test-install-operators test-install test-smoke

.PHONY: help
help:
	@echo "Build targets:"
	@echo "  package-and-update   Package charts and update KOTS versions"
	@echo "  clean                Remove build artifacts"
	@echo "  update-dependencies  Update Helm chart dependencies"
	@echo "  add-helm-repositories  Add required Helm repos"
	@echo "  release              Package and create a Replicated release"
	@echo ""
	@echo "Test targets:"
	@echo "  test-lint            Lint and template-render the chart"
	@echo "  test-install-operators  Install cert-manager and CloudNativePG"
	@echo "  test-install         Helm install Gitea with CI values"
	@echo "  test-smoke           Run Python smoke tests"
	@echo "  test-all             Full test sequence (lint -> operators -> install -> smoke)"
