manifests_dir := $(shell pwd)/kots
chart_archives := $(wildcard $(manifests_dir)/*.tgz)

ARGS = $(filter-out $@,$(MAKECMDGOALS))
%:
	@:

SHELL := /bin/bash
.SHELLFLAGS = -x +u -c

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

HELM_CHARTS_DIR = ./charts
KOTS_DIR        = ./kots

VAULTWARDEN_CHART_PATH = ./charts/vaultwarden/Chart.yaml

# CMX defaults — override on the command line as needed:
#   make cmx-create CLUSTER_NAME=my-test INSTANCE_TYPE=r1.xlarge
CLUSTER_NAME  ?= vaultwarden-kurl
INSTANCE_TYPE ?= r1.xlarge
DISK_GB       ?= 100
TTL           ?= 4h

# Helm test defaults
CI_VALUES    = tests/helm/ci-values.yaml
RELEASE_NAME = vaultwarden
NAMESPACE    = default

# ---------------------------------------------------------------------------
# Version helpers
# ---------------------------------------------------------------------------

define get_vaultwarden_chart_version
	cat $(VAULTWARDEN_CHART_PATH) | grep '^version:' | cut -d ' ' -f 2
endef

define get_kots_chart_version
	grep 'chartVersion:' $(1) | sed 's/.*chartVersion: //'
endef

define get_helm_chart_version
    helm show chart $(1) | grep '^version:' | cut -d ' ' -f 2
endef


# ===================================================================
#  Build targets
# ===================================================================

.PHONY: update-dependencies
update-dependencies: ## Update Helm chart dependencies (pulls Replicated SDK)
	@for chart_dir in $(HELM_CHARTS_DIR)/*; do \
	    if [ -d $$chart_dir ]; then \
	        echo "Updating dependencies for $$chart_dir"; \
	        helm dependency update $$chart_dir; \
	    fi; \
	done

.PHONY: package-and-update
package-and-update: clean ## Package Helm chart and sync version into KOTS HelmChart CR
	@for chart in $(HELM_CHARTS_DIR)/*; do \
	    echo "Packaging $$chart"; \
	    helm package $$chart -d $(KOTS_DIR); \
	    version=$$(eval $(call get_helm_chart_version,$$chart)); \
	    chart_name=$$(basename $$chart); \
	    echo "Updating chartVersion to $$version in $(KOTS_DIR)/$$chart_name-chart.yaml"; \
	    sed -i.bak 's|chartVersion: [0-9a-zA-Z.-]*|chartVersion: '$$version'|g' $(KOTS_DIR)/$$chart_name-chart.yaml && rm -f $(KOTS_DIR)/$$chart_name-chart.yaml.bak; \
	done

.PHONY: clean
clean: ## Remove packaged chart archives and temp directories
	@echo "Cleaning up build artifacts in $(KOTS_DIR)"
	@rm -f $(KOTS_DIR)/*.tgz
	@echo "Removing old Helm tmpcharts-* directories"
	@rm -rf $(HELM_CHARTS_DIR)/*/tmpcharts-*


# ===================================================================
#  Release targets — create a Replicated release from the KOTS dir
# ===================================================================

.PHONY: release
release: package-and-update ## Package chart and create a Replicated release on Unstable
	@chart_version=$$(eval $(call get_vaultwarden_chart_version)); \
	echo "Creating Replicated release version $$chart_version"; \
	replicated release create --yaml-dir $(KOTS_DIR) --promote Unstable --version "$$chart_version"


# ===================================================================
#  CMX targets — provision and manage kURL clusters via Compatibility Matrix
# ===================================================================
#
#  Typical workflow:
#    1. make release                 — push a release to Unstable
#    2. Promote the release and create a customer with kURL entitlement
#       in the Vendor Portal
#    3. make cmx-create LICENSE_ID=<id>  — spin up a kURL cluster
#    4. make cmx-status              — poll until the cluster is ready
#    5. make cmx-shell               — open a shell to configure via KOTS admin
#    6. make cmx-smoke               — run smoke tests against the cluster
#    7. make cmx-delete              — tear down when done
#

.PHONY: cmx-create
cmx-create: ## Create a kURL cluster in CMX (requires LICENSE_ID=<...>)
ifndef LICENSE_ID
	$(error LICENSE_ID is required. Get it from the Vendor Portal customer page.)
endif
	replicated cluster create \
		--distribution kurl \
		--instance-type $(INSTANCE_TYPE) \
		--disk $(DISK_GB) \
		--license-id $(LICENSE_ID) \
		--ttl $(TTL) \
		--name $(CLUSTER_NAME)
	@echo ""
	@echo "Cluster creation started. Run 'make cmx-status' to check progress."

.PHONY: cmx-status
cmx-status: ## List CMX clusters and their status
	replicated cluster ls

.PHONY: cmx-shell
cmx-shell: ## Open a shell into the CMX cluster (requires CLUSTER_ID=<...>)
ifndef CLUSTER_ID
	$(error CLUSTER_ID is required. Run 'make cmx-status' to find it.)
endif
	replicated cluster shell $(CLUSTER_ID)

.PHONY: cmx-kubeconfig
cmx-kubeconfig: ## Write the CMX cluster kubeconfig to ./kubeconfig (requires CLUSTER_ID=<...>)
ifndef CLUSTER_ID
	$(error CLUSTER_ID is required. Run 'make cmx-status' to find it.)
endif
	replicated cluster kubeconfig $(CLUSTER_ID) > kubeconfig
	@echo "Kubeconfig written to ./kubeconfig"
	@echo "Export it:  export KUBECONFIG=$$(pwd)/kubeconfig"

.PHONY: cmx-expose-admin
cmx-expose-admin: ## Expose the KOTS admin console port on CMX (requires CLUSTER_ID=<...>)
ifndef CLUSTER_ID
	$(error CLUSTER_ID is required. Run 'make cmx-status' to find it.)
endif
	replicated cluster port expose $(CLUSTER_ID) --port 8800
	@echo ""
	@echo "The KOTS admin console should be reachable at the URL above on port 8800."

.PHONY: cmx-delete
cmx-delete: ## Delete a CMX cluster (requires CLUSTER_ID=<...>)
ifndef CLUSTER_ID
	$(error CLUSTER_ID is required. Run 'make cmx-status' to find it.)
endif
	replicated cluster rm $(CLUSTER_ID)
	@echo "Cluster $(CLUSTER_ID) deletion requested."


# ===================================================================
#  Test targets
# ===================================================================

.PHONY: test-lint
test-lint: update-dependencies ## Lint and template-render the chart
	helm lint ./charts/vaultwarden
	helm template $(RELEASE_NAME) ./charts/vaultwarden -f $(CI_VALUES) > /dev/null

.PHONY: test-install
test-install: update-dependencies ## Helm install Vaultwarden with CI values (requires a running cluster)
	helm install $(RELEASE_NAME) ./charts/vaultwarden \
		-f $(CI_VALUES) \
		--namespace $(NAMESPACE) \
		--wait --timeout 5m

.PHONY: test-smoke
test-smoke: ## Run smoke tests against a running Vaultwarden instance
	python3 -m venv ./venv
	./venv/bin/pip install -r tests/requirements.txt
	./venv/bin/python tests/smoke_test.py \
		--release $(RELEASE_NAME) --namespace $(NAMESPACE)

.PHONY: test-all
test-all: test-lint test-install test-smoke ## Full test sequence (lint → install → smoke)


# ===================================================================
#  Help
# ===================================================================

.PHONY: help
help: ## Show this help
	@echo "Build targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; /^[^c]/ {printf "  %-22s %s\n", $$1, $$2}'
	@echo ""
	@echo "CMX targets (kURL cluster management):"
	@grep -E '^cmx-[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-22s %s\n", $$1, $$2}'
	@echo ""
	@echo "Test targets:"
	@grep -E '^test-[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-22s %s\n", $$1, $$2}'
