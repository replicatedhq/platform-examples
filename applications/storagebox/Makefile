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

# Path to Storagebox's Chart.yaml
STORAGEBOX_CHART_PATH = ./charts/storagebox/Chart.yaml

# Cluster configuration
CLUSTER_NAME ?= storagebox-test-$(shell date +%s)
CLUSTER_PREFIX ?= storagebox
CHANNEL ?= test-v018-k8s131
DISTRIBUTION ?= k3s
K8S_VERSION ?= 1.33
INSTANCE_TYPE ?= r1.medium
NODE_COUNT ?= 1
DISK_SIZE ?= 50
TTL ?= 4h

# CMX VM configuration (for Embedded Cluster testing)
VM_DISTRIBUTION ?= ubuntu
VM_VERSION ?= 22.04
ADMIN_CONSOLE_PORT ?= 30000
ADMIN_PASSWORD ?= password
EC_VERSION := $(shell grep 'version:' $(KOTS_DIR)/ec.yaml | head -1 | awk '{print $$2}')
EC_DOWNLOAD_URL ?= https://get.embeddedcluster.com/$(EC_VERSION)/$(EC_VERSION).tgz
EC_AUTH_TOKEN ?=
EC_ARCHIVE_NAME ?= storagebox-ec.tgz
CONFIG_VALUES_FILE ?= development-values.yaml

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
	    sed -i.bak "s|chartVersion: [0-9a-zA-Z.-]*|chartVersion: $$version|g" $(KOTS_DIR)/$$chart_name-chart.yaml && rm -f $(KOTS_DIR)/$$chart_name-chart.yaml.bak; \
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
# CMX VM Management (Embedded Cluster Testing)
# ============================================================================

.PHONY: vm-1node
vm-1node:
	@echo "Creating 1-node CMX VM for Embedded Cluster testing"
	@echo "Cluster prefix: $(CLUSTER_PREFIX)"
	@replicated vm create \
		--name "$(CLUSTER_PREFIX)-node-1" \
		--distribution $(VM_DISTRIBUTION) --version $(VM_VERSION) \
		--count 1 --instance-type $(INSTANCE_TYPE) --disk $(DISK_SIZE) --ttl $(TTL) \
		--tag cluster=$(CLUSTER_PREFIX) \
		--wait 5m
	@echo "✓ VM created successfully"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Download EC: make vm-download-ec CLUSTER_PREFIX=$(CLUSTER_PREFIX)"
	@echo "  2. Expose ports: make vm-expose-ports CLUSTER_PREFIX=$(CLUSTER_PREFIX)"
	@echo "  3. Install EC:"
	@echo "     - UI mode:      make vm-ec-install CLUSTER_PREFIX=$(CLUSTER_PREFIX)"
	@echo "     - Headless:     make vm-ec-install-headless CLUSTER_PREFIX=$(CLUSTER_PREFIX)"

.PHONY: vm-3node
vm-3node:
	@echo "Creating 3-node CMX VM cluster for Embedded Cluster testing"
	@echo "Cluster prefix: $(CLUSTER_PREFIX)"
	@echo ""
	@echo "Creating node-1 to establish network..."
	@replicated vm create \
		--name "$(CLUSTER_PREFIX)-node-1" \
		--distribution $(VM_DISTRIBUTION) --version $(VM_VERSION) \
		--count 1 --instance-type $(INSTANCE_TYPE) --disk $(DISK_SIZE) --ttl $(TTL) \
		--tag cluster=$(CLUSTER_PREFIX) --tag role=control --tag node_number=1 \
		--wait 5m
	@network_id=$$(replicated vm ls --output json | jq -r '.[] | select(.name == "$(CLUSTER_PREFIX)-node-1") | .network_id' | head -1); \
	echo "Network established. Network ID: $$network_id"; \
	echo ""; \
	echo "Creating nodes 2-3 in parallel..."; \
	replicated vm create \
		--name "$(CLUSTER_PREFIX)-node-2" \
		--distribution $(VM_DISTRIBUTION) --version $(VM_VERSION) \
		--count 1 --instance-type $(INSTANCE_TYPE) --disk $(DISK_SIZE) --ttl $(TTL) \
		--network $$network_id \
		--tag cluster=$(CLUSTER_PREFIX) --tag role=control --tag node_number=2 \
		--wait 5m & \
	replicated vm create \
		--name "$(CLUSTER_PREFIX)-node-3" \
		--distribution $(VM_DISTRIBUTION) --version $(VM_VERSION) \
		--count 1 --instance-type $(INSTANCE_TYPE) --disk $(DISK_SIZE) --ttl $(TTL) \
		--network $$network_id \
		--tag cluster=$(CLUSTER_PREFIX) --tag role=control --tag node_number=3 \
		--wait 5m & \
	wait
	@echo "✓ 3-node cluster created successfully"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Download EC: make vm-download-ec CLUSTER_PREFIX=$(CLUSTER_PREFIX)"
	@echo "  2. Expose ports: make vm-expose-ports CLUSTER_PREFIX=$(CLUSTER_PREFIX)"
	@echo "  3. Install EC:"
	@echo "     - UI mode:      make vm-ec-install CLUSTER_PREFIX=$(CLUSTER_PREFIX)"
	@echo "     - Headless:     make vm-ec-install-headless CLUSTER_PREFIX=$(CLUSTER_PREFIX)"

.PHONY: vm-list
vm-list:
	@replicated vm ls

.PHONY: vm-status
vm-status:
	@echo "CMX VM Status for $(CLUSTER_PREFIX):"
	@echo "======================================"
	@replicated vm ls --output json | jq -r '.[] | select(.name | startswith("$(CLUSTER_PREFIX)-")) | "\(.name): \(.status) (\(.id))"' | sort

.PHONY: vm-cleanup
vm-cleanup:
	@echo "Cleaning up CMX VMs for cluster: $(CLUSTER_PREFIX)"
	@replicated vm ls --output json | jq -r '.[] | select(.name | startswith("$(CLUSTER_PREFIX)-")) | "\(.id) \(.name)"' | \
	while read vm_id vm_name; do \
		echo "Deleting $$vm_name ($$vm_id)..."; \
		replicated vm rm $$vm_id; \
	done
	@echo "✓ Cleanup completed for $(CLUSTER_PREFIX)"

.PHONY: vm-download-ec
vm-download-ec:
	@echo "Downloading Embedded Cluster binary to all nodes"
	@echo "EC Version: $(EC_VERSION)"
	@echo "Download URL: $(EC_DOWNLOAD_URL)"
	@vm_list=$$(replicated vm ls --output json | jq -r '.[] | select(.name | startswith("$(CLUSTER_PREFIX)-")) | select(.status == "running") | .name'); \
	if [ -z "$$vm_list" ]; then \
		echo "ERROR: No running VMs found with prefix '$(CLUSTER_PREFIX)'"; \
		exit 1; \
	fi; \
	echo "Found VMs:"; \
	echo "$$vm_list" | sed 's/^/  - /'; \
	echo ""; \
	for vm_name in $$vm_list; do \
		echo "Downloading to $$vm_name..."; \
		vm_id=$$(replicated vm ls --output json | jq -r '.[] | select(.name == "'$$vm_name'" and .status == "running") | .id'); \
		ssh_endpoint=$$(replicated vm ssh-endpoint $$vm_id); \
		ssh -o StrictHostKeyChecking=no $$ssh_endpoint "\
			cd ~ && \
			echo 'Downloading EC binary...' && \
			curl -fsSL '$(EC_DOWNLOAD_URL)' \
				$(if $(EC_AUTH_TOKEN),-H 'Authorization: $(EC_AUTH_TOKEN)') \
				-o $(EC_ARCHIVE_NAME) && \
			tar -xzf $(EC_ARCHIVE_NAME) && \
			chmod +x storagebox && \
			echo '✓ EC binary downloaded and extracted' \
		" || { echo "ERROR: Failed to download to $$vm_name"; exit 1; }; \
	done; \
	echo ""; \
	echo "✓ EC binary downloaded to all nodes"

.PHONY: vm-expose-ports
vm-expose-ports:
	@vm_id=$$(replicated vm ls --output json | jq -r '.[] | select(.name == "$(CLUSTER_PREFIX)-node-1" and .status == "running") | .id'); \
	if [ -z "$$vm_id" ]; then \
		echo "ERROR: $(CLUSTER_PREFIX)-node-1 not found or not running"; \
		exit 1; \
	fi; \
	echo "Exposing admin console port $(ADMIN_CONSOLE_PORT) on node-1..."; \
	replicated vm port expose $$vm_id --port $(ADMIN_CONSOLE_PORT); \
	echo ""; \
	echo "✓ Ports exposed successfully"; \
	echo ""; \
	echo "Admin Console URL:"; \
	hostname=$$(replicated vm port ls $$vm_id --output json | jq -r '.[] | select(.upstream_port == $(ADMIN_CONSOLE_PORT)) | .hostname'); \
	echo "  https://$$hostname"

.PHONY: vm-copy-license
vm-copy-license:
	@vm_id=$$(replicated vm ls --output json | jq -r '.[] | select(.name == "$(CLUSTER_PREFIX)-node-1" and .status == "running") | .id'); \
	if [ -z "$$vm_id" ]; then \
		echo "ERROR: $(CLUSTER_PREFIX)-node-1 not found or not running"; \
		exit 1; \
	fi; \
	ssh_endpoint=$$(replicated vm ssh-endpoint $$vm_id); \
	echo "Getting license for storagebox..."; \
	customer_id=$$(replicated customer ls --output json | jq -r '.[0].id'); \
	if [ -z "$$customer_id" ]; then \
		echo "ERROR: No customers found. Create a customer first."; \
		exit 1; \
	fi; \
	replicated customer download-license --customer "$$customer_id" > /tmp/storagebox-license.yaml; \
	echo "Copying license to $(CLUSTER_PREFIX)-node-1..."; \
	ssh_host=$$(echo $$ssh_endpoint | sed 's|ssh://||' | sed 's|:| |'); \
	scp -o StrictHostKeyChecking=no -P $$(echo $$ssh_host | awk '{print $$2}') /tmp/storagebox-license.yaml $$(echo $$ssh_host | awk '{print $$1}'):license.yaml; \
	rm /tmp/storagebox-license.yaml; \
	echo "✓ License copied successfully"

.PHONY: vm-copy-config
vm-copy-config:
	@vm_id=$$(replicated vm ls --output json | jq -r '.[] | select(.name == "$(CLUSTER_PREFIX)-node-1" and .status == "running") | .id'); \
	if [ -z "$$vm_id" ]; then \
		echo "ERROR: $(CLUSTER_PREFIX)-node-1 not found or not running"; \
		exit 1; \
	fi; \
	ssh_endpoint=$$(replicated vm ssh-endpoint $$vm_id); \
	echo "Copying config values to $(CLUSTER_PREFIX)-node-1..."; \
	ssh_host=$$(echo $$ssh_endpoint | sed 's|ssh://||' | sed 's|:| |'); \
	scp -o StrictHostKeyChecking=no -P $$(echo $$ssh_host | awk '{print $$2}') $(CONFIG_VALUES_FILE) $$(echo $$ssh_host | awk '{print $$1}'):config-values.yaml; \
	echo "✓ Config values copied successfully"

.PHONY: vm-ec-install
vm-ec-install:
	@vm_id=$$(replicated vm ls --output json | jq -r '.[] | select(.name == "$(CLUSTER_PREFIX)-node-1" and .status == "running") | .id'); \
	if [ -z "$$vm_id" ]; then \
		echo "ERROR: $(CLUSTER_PREFIX)-node-1 not found or not running"; \
		exit 1; \
	fi; \
	ssh_endpoint=$$(replicated vm ssh-endpoint $$vm_id); \
	echo "Installing Embedded Cluster on $(CLUSTER_PREFIX)-node-1 (UI mode)..."; \
	echo ""; \
	ssh -o StrictHostKeyChecking=no $$ssh_endpoint "\
		sudo ./storagebox install \
			--admin-console-password $(ADMIN_PASSWORD) \
			--license ~/license.yaml \
	" && \
	echo "" && \
	echo "✓ Embedded Cluster installed successfully" && \
	echo "" && \
	echo "Admin Console:" && \
	hostname=$$(replicated vm port ls $$vm_id --output json | jq -r '.[] | select(.upstream_port == $(ADMIN_CONSOLE_PORT)) | .hostname'); \
	echo "  URL:      https://$$hostname" && \
	echo "  Password: $(ADMIN_PASSWORD)"

.PHONY: vm-ec-install-headless
vm-ec-install-headless: vm-copy-license vm-copy-config
	@vm_id=$$(replicated vm ls --output json | jq -r '.[] | select(.name == "$(CLUSTER_PREFIX)-node-1" and .status == "running") | .id'); \
	if [ -z "$$vm_id" ]; then \
		echo "ERROR: $(CLUSTER_PREFIX)-node-1 not found or not running"; \
		exit 1; \
	fi; \
	ssh_endpoint=$$(replicated vm ssh-endpoint $$vm_id); \
	echo "Installing Embedded Cluster on $(CLUSTER_PREFIX)-node-1 (headless mode)..."; \
	echo "Using config values from: $(CONFIG_VALUES_FILE)"; \
	echo ""; \
	ssh -o StrictHostKeyChecking=no $$ssh_endpoint "\
		sudo ./storagebox install \
			--admin-console-password $(ADMIN_PASSWORD) \
			--license ~/license.yaml \
			--config-values ~/config-values.yaml \
	" && \
	echo "" && \
	echo "✓ Embedded Cluster installed successfully (headless)" && \
	echo "" && \
	echo "Admin Console:" && \
	hostname=$$(replicated vm port ls $$vm_id --output json | jq -r '.[] | select(.upstream_port == $(ADMIN_CONSOLE_PORT)) | .hostname'); \
	echo "  URL:      https://$$hostname" && \
	echo "  Password: $(ADMIN_PASSWORD)" && \
	echo "" && \
	echo "Note: Application configured with values from $(CONFIG_VALUES_FILE)"


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
	@echo "CMX VM Management (Embedded Cluster Testing):"
	@echo "  make vm-1node                 - Create single-node CMX VM"
	@echo "  make vm-3node                 - Create 3-node CMX VM cluster"
	@echo "  make vm-list                  - List all CMX VMs"
	@echo "  make vm-status                - Show VM status for cluster"
	@echo "  make vm-cleanup               - Delete all VMs for cluster"
	@echo "  make vm-download-ec           - Download EC binary to all nodes"
	@echo "  make vm-expose-ports          - Expose admin console port"
	@echo "  make vm-copy-license          - Copy license to node-1"
	@echo "  make vm-copy-config           - Copy config values to node-1"
	@echo "  make vm-ec-install            - Install EC on node-1 (UI mode)"
	@echo "  make vm-ec-install-headless   - Install EC on node-1 (headless)"
	@echo ""
	@echo "Workflows:"
	@echo "  make test-cycle               - Full test cycle: release + cluster + ready"
	@echo ""
	@echo "Configuration (override with VARIABLE=value):"
	@echo "  CLUSTER_NAME                  - Cluster name (default: storagebox-test-<timestamp>)"
	@echo "  CLUSTER_PREFIX                - Cluster name prefix (default: storagebox)"
	@echo "  CHANNEL                       - Release channel (default: test-v018-k8s131)"
	@echo "  DISTRIBUTION                  - K8s distribution (default: k3s)"
	@echo "  K8S_VERSION                   - Kubernetes version (default: 1.33)"
	@echo "  INSTANCE_TYPE                 - Instance type (default: r1.medium)"
	@echo "  NODE_COUNT                    - Number of nodes (default: 1)"
	@echo "  DISK_SIZE                     - Disk size in GB (default: 50)"
	@echo "  TTL                           - Cluster TTL (default: 4h)"
	@echo ""
	@echo "Examples:"
	@echo "  # Regular cluster testing (KOTS)"
	@echo "  make cluster-create CLUSTER_NAME=my-test"
	@echo "  make deploy CLUSTER_NAME=my-test CHANNEL=test-v018-k8s131"
	@echo "  make cluster-status CLUSTER_NAME=my-test"
	@echo "  make cluster-rm CLUSTER_NAME=my-test"
	@echo ""
	@echo "  # Embedded Cluster testing (CMX VM) - UI mode"
	@echo "  make vm-1node CLUSTER_PREFIX=my-test"
	@echo "  make vm-download-ec CLUSTER_PREFIX=my-test"
	@echo "  make vm-expose-ports CLUSTER_PREFIX=my-test"
	@echo "  make vm-ec-install CLUSTER_PREFIX=my-test"
	@echo "  make vm-cleanup CLUSTER_PREFIX=my-test"
	@echo ""
	@echo "  # Embedded Cluster testing (CMX VM) - Headless mode"
	@echo "  make vm-1node CLUSTER_PREFIX=my-test"
	@echo "  make vm-download-ec CLUSTER_PREFIX=my-test"
	@echo "  make vm-expose-ports CLUSTER_PREFIX=my-test"
	@echo "  make vm-ec-install-headless CLUSTER_PREFIX=my-test"
	@echo "  make vm-cleanup CLUSTER_PREFIX=my-test"
	@echo ""
	@echo "Testing:"
	@echo "  make test-lint                - Helm lint the chart"
	@echo "  make test-install-operators   - Install all required operators"
	@echo "  make test-install             - Helm install storagebox with test values"
	@echo "  make test-smoke               - Run smoke tests"
	@echo "  make test-all                 - Full test sequence (lint -> operators -> install -> smoke)"


# ============================================================================
# Test Targets
# ============================================================================

TEST_NAMESPACE ?= storagebox

.PHONY: test-lint
test-lint:
	@echo "Linting storagebox chart..."
	helm lint ./charts/storagebox
	@echo "Template rendering with test values..."
	helm template storagebox ./charts/storagebox -f tests/helm/all-components.yaml > /dev/null
	@echo "Lint and template passed"

.PHONY: test-install-operators
test-install-operators:
	@echo "Installing operators matching kots/ec.yaml versions..."
	helm install cert-manager jetstack/cert-manager \
		--namespace cert-manager --create-namespace \
		--version v1.19.1 \
		--set crds.enabled=true \
		--set prometheus.enabled=false \
		--wait --timeout 5m
	helm install cloudnative-pg cnpg/cloudnative-pg \
		--namespace cnpg --create-namespace \
		--version 0.27.0 \
		--wait --timeout 5m
	helm install minio-operator minio-operator/operator \
		--namespace minio --create-namespace \
		--version 7.1.1 \
		--wait --timeout 5m
	helm install k8ssandra-operator k8ssandra/k8ssandra-operator \
		--namespace k8ssandra-operator --create-namespace \
		--version 1.22.0 \
		--set global.clusterScoped=true \
		--wait --timeout 5m
	@echo "All operators installed"

.PHONY: test-install
test-install:
	@echo "Installing storagebox with test values..."
	helm install storagebox ./charts/storagebox \
		--namespace $(TEST_NAMESPACE) --create-namespace \
		-f tests/helm/all-components.yaml \
		--wait --timeout 10m
	@echo "Storagebox installed"

.PHONY: test-smoke
test-smoke:
	@echo "Running smoke tests..."
	pip install -q -r tests/requirements.txt
	python tests/smoke_test.py $(TEST_NAMESPACE)

.PHONY: test-all
test-all: test-lint test-install-operators test-install test-smoke
	@echo "All tests passed"
