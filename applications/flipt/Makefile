.PHONY: help lint package update-deps install uninstall upgrade test clean release

CHART_DIR := chart
CHART_NAME := flipt
NAMESPACE := flipt
RELEASE_NAME := flipt
RELEASE_DIR := release
REPLICATED_DIR := replicated
CHART_VERSION := $(shell grep '^version:' $(CHART_DIR)/Chart.yaml | awk '{print $$2}')

help: ## Display this help message
	@echo "Flipt Helm Chart Management"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

lint: ## Lint the Helm chart
	@echo "Linting Helm chart..."
	helm lint $(CHART_DIR)

package: lint ## Package the Helm chart
	@echo "Packaging Helm chart..."
	@mkdir -p $(RELEASE_DIR)
	helm package $(CHART_DIR) -d $(RELEASE_DIR)

update-deps: ## Update Helm chart dependencies
	@echo "Adding Helm repositories..."
	helm repo add flipt https://helm.flipt.io || true
	helm repo add bitnami https://charts.bitnami.com/bitnami || true
	helm repo add cnpg https://cloudnative-pg.github.io/charts || true
	helm repo add replicated https://charts.replicated.com || true
	helm repo update
	@echo "Updating chart dependencies..."
	cd $(CHART_DIR) && helm dependency update

install: ## Install the chart (operator included as dependency)
	@echo "Installing $(CHART_NAME)..."
	@echo "Note: This includes CloudNativePG operator installation, which may take a few minutes..."
	helm install $(RELEASE_NAME) $(CHART_DIR) \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait \
		--wait-for-jobs \
		--timeout 15m

install-no-operator: ## Install without CloudNativePG operator (use if already installed)
	@echo "Installing $(CHART_NAME) without operator..."
	helm install $(RELEASE_NAME) $(CHART_DIR) \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--set cloudnative-pg.enabled=false \
		--wait \
		--wait-for-jobs \
		--timeout 10m

uninstall: ## Uninstall the chart
	@echo "Uninstalling $(CHART_NAME)..."
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)

upgrade: ## Upgrade the chart
	@echo "Upgrading $(CHART_NAME)..."
	helm upgrade $(RELEASE_NAME) $(CHART_DIR) \
		--namespace $(NAMESPACE) \
		--wait \
		--timeout 10m

template: ## Render chart templates locally
	@echo "Rendering templates..."
	helm template $(RELEASE_NAME) $(CHART_DIR) \
		--namespace $(NAMESPACE) \
		--debug

test: ## Run Helm tests
	@echo "Running Helm tests..."
	helm test $(RELEASE_NAME) --namespace $(NAMESPACE)

status: ## Show release status
	@echo "Release status:"
	helm status $(RELEASE_NAME) --namespace $(NAMESPACE)

values: ## Show computed values
	@echo "Computed values:"
	helm get values $(RELEASE_NAME) --namespace $(NAMESPACE)

manifest: ## Show deployed manifest
	@echo "Deployed manifest:"
	helm get manifest $(RELEASE_NAME) --namespace $(NAMESPACE)

logs: ## Tail Flipt logs
	@echo "Tailing Flipt logs..."
	kubectl logs -l app.kubernetes.io/name=flipt -n $(NAMESPACE) --tail=100 -f

clean: ## Clean generated files
	@echo "Cleaning generated files..."
	rm -rf $(CHART_DIR)/charts/*.tgz
	rm -rf $(CHART_DIR)/Chart.lock
	rm -rf $(RELEASE_DIR)/*.tgz

clean-install: clean update-deps install ## Clean rebuild and install

port-forward: ## Port forward to Flipt service
	@echo "Port forwarding to Flipt (http://localhost:8080)..."
	kubectl port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME)-flipt 8080:8080

replicated-lint: ## Lint Replicated KOTS configs
	@echo "Linting KOTS configuration..."
	replicated release lint --yaml-dir $(REPLICATED_DIR)/

replicated-create: package ## Create a new Replicated release (includes packaging)
	@echo "Creating Replicated release..."
	replicated release create --auto --yaml-dir $(REPLICATED_DIR)/

preflight: ## Run preflight checks
	@echo "Running preflight checks..."
	kubectl preflight $(CHART_DIR)/templates/secret-preflights.yaml

support-bundle: ## Generate support bundle
	@echo "Generating support bundle..."
	kubectl support-bundle $(CHART_DIR)/templates/secret-supportbundle.yaml

check-deps: ## Verify all required tools are installed
	@echo "Checking dependencies..."
	@command -v helm >/dev/null 2>&1 || { echo "helm is not installed"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "kubectl is not installed"; exit 1; }
	@echo "All dependencies satisfied!"

release: package ## Lint, package, update Replicated config, and create release
	@# Clean previous chart archives from replicated dir
	@rm -f $(REPLICATED_DIR)/$(CHART_NAME)-*.tgz
	@# Copy packaged chart to replicated dir
	@cp $(RELEASE_DIR)/$(CHART_NAME)-$(CHART_VERSION).tgz $(REPLICATED_DIR)/
	@# Update chartVersion in HelmChart config
	@sed -i '' 's/chartVersion:.*/chartVersion: $(CHART_VERSION)/' $(REPLICATED_DIR)/kots-helm-chart.yaml
	@echo "Chart $(CHART_NAME)-$(CHART_VERSION) packaged and staged in $(REPLICATED_DIR)/"
	@echo ""
	@# Determine next version by bumping previous release patch version
	@PREV_VERSION=$$(replicated release ls 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1); \
	if [ -n "$$PREV_VERSION" ]; then \
		MAJOR=$$(echo $$PREV_VERSION | cut -d. -f1); \
		MINOR=$$(echo $$PREV_VERSION | cut -d. -f2); \
		PATCH=$$(echo $$PREV_VERSION | cut -d. -f3); \
		NEXT_VERSION="$$MAJOR.$$MINOR.$$((PATCH + 1))"; \
		echo "Previous release: $$PREV_VERSION"; \
	else \
		NEXT_VERSION="$(CHART_VERSION)"; \
		echo "No previous release found, defaulting to chart version"; \
	fi; \
	echo "Suggested version: $$NEXT_VERSION"; \
	echo ""; \
	read -p "Release version [$$NEXT_VERSION]: " INPUT_VERSION; \
	VERSION=$${INPUT_VERSION:-$$NEXT_VERSION}; \
	echo ""; \
	read -p "Release notes: " RELEASE_NOTES; \
	if [ -z "$$RELEASE_NOTES" ]; then \
		echo "Error: release notes are required"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "Creating Replicated release v$$VERSION..."; \
	replicated release create \
		--promote Unstable \
		--yaml-dir $(REPLICATED_DIR) \
		--version "$$VERSION" \
		--release-notes "$$RELEASE_NOTES"

# Development helpers
dev-install: update-deps install ## Update dependencies and install

dev-upgrade: update-deps upgrade ## Update dependencies and upgrade

watch-pods: ## Watch pod status
	kubectl get pods -n $(NAMESPACE) -w
