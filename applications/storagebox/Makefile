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

# Path to Storagebox's Chart.yaml
STORAGEBOX_CHART_PATH = ./charts/storagebox/Chart.yaml

# Cluster configuration
CLUSTER_NAME ?= storagebox-test-$(shell date +%s)
CLUSTER_PREFIX ?= storagebox
CHANNEL ?= test-v018-k8s131
DISTRIBUTION ?= k3s
K8S_VERSION ?= 1.31
INSTANCE_TYPE ?= r1.medium
NODE_COUNT ?= 1
DISK_SIZE ?= 50
TTL ?= 4h

# Function to extract version from Chart.yaml
define get_storagebox_chart_version
	cat $(STORAGEBOX_CHART_PATH) | grep '^version:' | cut -d ' ' -f 2
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
	    sed -i '' 's|chartVersion: [0-9a-zA-Z.-]*|chartVersion: '$$version'|g' $(KOTS_DIR)/$$chart_name-chart.yaml; \
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
	    grep 'dependencies:' -A 10 $$chart_file | grep 'repository:' | awk '{print $$2}' | while read repo; do \
	        if ! helm repo list | grep -q "^$$repo_name[[:space:]]"; then \
	            echo "Adding Helm repo $$repo_name from $$repo"; \
	            helm repo add $$repo_name $$repo || true; \
	        fi; \
	    done; \
	done
	@helm repo update


# ============================================================================
# Validation Targets (Four-Way Contract)
# ============================================================================

.PHONY: validate-config
validate-config: validate-helmchart-refs validate-development-values
	@echo "✓ All validation checks passed"

.PHONY: validate-helmchart-refs
validate-helmchart-refs:
	@echo "Validating ConfigOption references in KOTS HelmChart..."
	@missing_refs=0; \
	while IFS= read -r config_name; do \
		if ! grep -q "name: $$config_name" $(KOTS_DIR)/kots-config.yaml; then \
			echo "ERROR: ConfigOption '$$config_name' referenced in storagebox-chart.yaml but not defined in kots-config.yaml"; \
			missing_refs=$$((missing_refs + 1)); \
		fi; \
	done < <(grep -oE 'ConfigOption(Equals)? "[^"]+' $(KOTS_DIR)/storagebox-chart.yaml | awk -F'"' '{print $$2}' | sort -u); \
	if [ $$missing_refs -gt 0 ]; then \
		echo "✗ Found $$missing_refs missing ConfigOption reference(s)"; \
		exit 1; \
	else \
		echo "✓ All ConfigOption references are valid"; \
	fi

.PHONY: validate-development-values
validate-development-values:
	@echo "Validating development-values.yaml matches kots-config.yaml..."
	@missing_values=0; \
	while IFS= read -r config_name; do \
		if ! grep -q "$$config_name:" development-values.yaml; then \
			echo "ERROR: Config item '$$config_name' defined in kots-config.yaml but missing from development-values.yaml"; \
			missing_values=$$((missing_values + 1)); \
		fi; \
	done < <(grep '^    - name: ' $(KOTS_DIR)/kots-config.yaml | sed 's/.*name: //' | sort -u); \
	if [ $$missing_values -gt 0 ]; then \
		echo "✗ Found $$missing_values missing config value(s) in development-values.yaml"; \
		exit 1; \
	else \
		echo "✓ All config items are present in development-values.yaml"; \
	fi


.PHONY: release
release: package-and-update
	@chart_version=$$(eval $(call get_storagebox_chart_version)); \
	echo "Creating a new release with Replicated using version $$chart_version"; \
	replicated release create --yaml-dir $(KOTS_DIR) --promote Unstable --version "$$chart_version"


# ============================================================================
# Cluster Management Targets
# ============================================================================

.PHONY: cluster-create
cluster-create:
	@echo "Creating single-node test cluster: $(CLUSTER_NAME)"
	@replicated cluster create \
		--name "$(CLUSTER_NAME)" \
		--distribution "$(DISTRIBUTION)" \
		--version "$(K8S_VERSION)" \
		--disk "$(DISK_SIZE)" \
		--instance-type "$(INSTANCE_TYPE)" \
		--nodes "$(NODE_COUNT)" \
		--ttl "$(TTL)"
	@echo "Cluster created successfully"
	@echo "Use 'make cluster-kubeconfig CLUSTER_NAME=$(CLUSTER_NAME)' to get kubeconfig"

.PHONY: cluster-list
cluster-list:
	@echo "Listing all clusters:"
	@replicated cluster ls

.PHONY: cluster-kubeconfig
cluster-kubeconfig:
	@if [ -z "$(CLUSTER_NAME)" ]; then \
		echo "Error: CLUSTER_NAME is required"; \
		echo "Usage: make cluster-kubeconfig CLUSTER_NAME=<name>"; \
		exit 1; \
	fi
	@echo "Fetching kubeconfig for cluster: $(CLUSTER_NAME)"
	@mkdir -p ~/.kube
	@replicated cluster kubeconfig --name "$(CLUSTER_NAME)" > ~/.kube/$(CLUSTER_NAME)-config
	@echo "Kubeconfig saved to: ~/.kube/$(CLUSTER_NAME)-config"
	@echo "Set KUBECONFIG: export KUBECONFIG=~/.kube/$(CLUSTER_NAME)-config"

.PHONY: cluster-status
cluster-status:
	@if [ -z "$(CLUSTER_NAME)" ]; then \
		echo "Error: CLUSTER_NAME is required"; \
		echo "Usage: make cluster-status CLUSTER_NAME=<name>"; \
		exit 1; \
	fi
	@echo "Getting status for cluster: $(CLUSTER_NAME)"
	@export KUBECONFIG=~/.kube/$(CLUSTER_NAME)-config && kubectl get nodes
	@export KUBECONFIG=~/.kube/$(CLUSTER_NAME)-config && kubectl get pods -A

.PHONY: cluster-rm
cluster-rm:
	@if [ -z "$(CLUSTER_NAME)" ]; then \
		echo "Error: CLUSTER_NAME is required"; \
		echo "Usage: make cluster-rm CLUSTER_NAME=<name>"; \
		exit 1; \
	fi
	@echo "Deleting cluster: $(CLUSTER_NAME)"
	@CLUSTER_ID=$$(replicated cluster ls --output json | jq -r '.[] | select(.name == "$(CLUSTER_NAME)") | .id'); \
	if [ -z "$$CLUSTER_ID" ]; then \
		echo "Cluster not found: $(CLUSTER_NAME)"; \
		exit 1; \
	fi; \
	replicated cluster rm "$$CLUSTER_ID"
	@rm -f ~/.kube/$(CLUSTER_NAME)-config
	@echo "Cluster deleted successfully"


# ============================================================================
# Deployment Targets
# ============================================================================

.PHONY: deploy
deploy:
	@if [ -z "$(CLUSTER_NAME)" ]; then \
		echo "Error: CLUSTER_NAME is required"; \
		echo "Usage: make deploy CLUSTER_NAME=<name> CHANNEL=<channel>"; \
		exit 1; \
	fi
	@echo "Deploying storagebox to cluster: $(CLUSTER_NAME) from channel: $(CHANNEL)"
	@echo "Getting license for channel..."
	@CUSTOMER_ID=$$(replicated customer ls --output json | jq -r '.[0].id'); \
	LICENSE=$$(replicated customer download-license --customer "$$CUSTOMER_ID" --output json | jq -r .license); \
	echo "Installing application..."; \
	export KUBECONFIG=~/.kube/$(CLUSTER_NAME)-config && \
	echo "$$LICENSE" | kubectl kots install storagebox \
		--namespace default \
		--shared-password password \
		--license-file - \
		--no-port-forward

.PHONY: deploy-status
deploy-status:
	@if [ -z "$(CLUSTER_NAME)" ]; then \
		echo "Error: CLUSTER_NAME is required"; \
		echo "Usage: make deploy-status CLUSTER_NAME=<name>"; \
		exit 1; \
	fi
	@echo "Checking deployment status in cluster: $(CLUSTER_NAME)"
	@export KUBECONFIG=~/.kube/$(CLUSTER_NAME)-config && \
	kubectl kots get apps -n default

.PHONY: deploy-logs
deploy-logs:
	@if [ -z "$(CLUSTER_NAME)" ]; then \
		echo "Error: CLUSTER_NAME is required"; \
		echo "Usage: make deploy-logs CLUSTER_NAME=<name> [POD=<pod-name>]"; \
		exit 1; \
	fi
	@export KUBECONFIG=~/.kube/$(CLUSTER_NAME)-config && \
	if [ -n "$(POD)" ]; then \
		kubectl logs $(POD) -n default --tail=100 -f; \
	else \
		echo "Available pods:"; \
		kubectl get pods -n default; \
	fi


# ============================================================================
# Helper Targets
# ============================================================================

.PHONY: test-cycle
test-cycle: clean package-and-update
	@echo "=== Starting full test cycle ==="
	@chart_version=$$(eval $(call get_storagebox_chart_version)); \
	echo "1. Creating release version $$chart_version to channel $(CHANNEL)..."; \
	replicated release create --yaml-dir $(KOTS_DIR) --promote $(CHANNEL) --version "$$chart_version"; \
	echo "2. Creating test cluster..."; \
	$(MAKE) cluster-create CLUSTER_NAME="$(CLUSTER_PREFIX)-$$chart_version"; \
	echo "3. Waiting for cluster to be ready (60s)..."; \
	sleep 60; \
	echo "4. Getting kubeconfig..."; \
	$(MAKE) cluster-kubeconfig CLUSTER_NAME="$(CLUSTER_PREFIX)-$$chart_version"; \
	echo "=== Test cluster ready ==="; \
	echo "Cluster: $(CLUSTER_PREFIX)-$$chart_version"; \
	echo "Channel: $(CHANNEL)"; \
	echo "Version: $$chart_version"; \
	echo ""; \
	echo "Next steps:"; \
	echo "  make deploy CLUSTER_NAME=$(CLUSTER_PREFIX)-$$chart_version CHANNEL=$(CHANNEL)"; \
	echo "  make cluster-status CLUSTER_NAME=$(CLUSTER_PREFIX)-$$chart_version"; \
	echo "  make cluster-rm CLUSTER_NAME=$(CLUSTER_PREFIX)-$$chart_version"

.PHONY: help
help:
	@echo "Storagebox Makefile Commands"
	@echo ""
	@echo "Build & Release:"
	@echo "  make clean                    - Clean build artifacts"
	@echo "  make update-dependencies      - Update Helm chart dependencies"
	@echo "  make add-helm-repositories    - Add required Helm repositories"
	@echo "  make package-and-update       - Package charts and update versions"
	@echo "  make release                  - Create release and promote to Unstable"
	@echo ""
	@echo "Validation (Four-Way Contract):"
	@echo "  make validate-config          - Run all validation checks"
	@echo "  make validate-helmchart-refs  - Verify ConfigOption references"
	@echo "  make validate-development-values - Verify development-values.yaml"
	@echo ""
	@echo "Cluster Management:"
	@echo "  make cluster-create           - Create a single-node test cluster"
	@echo "  make cluster-list             - List all clusters"
	@echo "  make cluster-kubeconfig       - Get kubeconfig for a cluster"
	@echo "  make cluster-status           - Show cluster status and pods"
	@echo "  make cluster-rm               - Delete a cluster"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy                   - Deploy storagebox to cluster"
	@echo "  make deploy-status            - Check deployment status"
	@echo "  make deploy-logs              - View pod logs"
	@echo ""
	@echo "Workflows:"
	@echo "  make test-cycle               - Full test cycle: release + cluster + ready"
	@echo ""
	@echo "Configuration (override with VARIABLE=value):"
	@echo "  CLUSTER_NAME                  - Cluster name (default: storagebox-test-<timestamp>)"
	@echo "  CLUSTER_PREFIX                - Cluster name prefix (default: storagebox)"
	@echo "  CHANNEL                       - Release channel (default: test-v018-k8s131)"
	@echo "  DISTRIBUTION                  - K8s distribution (default: k3s)"
	@echo "  K8S_VERSION                   - Kubernetes version (default: 1.31)"
	@echo "  INSTANCE_TYPE                 - Instance type (default: r1.medium)"
	@echo "  NODE_COUNT                    - Number of nodes (default: 1)"
	@echo "  DISK_SIZE                     - Disk size in GB (default: 50)"
	@echo "  TTL                           - Cluster TTL (default: 4h)"
	@echo ""
	@echo "Examples:"
	@echo "  make cluster-create CLUSTER_NAME=my-test"
	@echo "  make deploy CLUSTER_NAME=my-test CHANNEL=test-v018-k8s131"
	@echo "  make cluster-status CLUSTER_NAME=my-test"
	@echo "  make cluster-rm CLUSTER_NAME=my-test"
