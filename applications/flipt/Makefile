.PHONY: help lint package update-deps install uninstall upgrade test clean

CHART_DIR := chart
CHART_NAME := flipt
NAMESPACE := flipt
RELEASE_NAME := flipt

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
	helm package $(CHART_DIR)

update-deps: ## Update Helm chart dependencies
	@echo "Adding Helm repositories..."
	helm repo add flipt https://helm.flipt.io || true
	helm repo add bitnami https://charts.bitnami.com/bitnami || true
	helm repo add cnpg https://cloudnative-pg.github.io/charts || true
	helm repo add replicated https://charts.replicated.com || true
	helm repo update
	@echo "Updating chart dependencies..."
	cd $(CHART_DIR) && helm dependency update

install-operator: ## Install CloudNativePG operator (required, run once per cluster)
	@echo "Installing CloudNativePG operator..."
	helm repo add cnpg https://cloudnative-pg.github.io/charts || true
	helm repo update
	helm upgrade --install cnpg \
		--namespace cnpg-system \
		--create-namespace \
		cnpg/cloudnative-pg
	@echo "Waiting for operator to be ready..."
	kubectl wait --for=condition=available --timeout=300s \
		deployment/cnpg-cloudnative-pg \
		-n cnpg-system || true
	@echo "✓ Operator ready!"

install: install-operator ## Install the chart (includes operator installation)
	@echo "Installing $(CHART_NAME)..."
	helm install $(RELEASE_NAME) $(CHART_DIR) \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait \
		--timeout 10m

setup-license: ## Set up Replicated development license
	@./scripts/setup-dev-license.sh

install-with-license: setup-license install-operator ## Set up license and install
	@if [ -f ".replicated/license.env" ]; then \
		. .replicated/license.env && \
		$(MAKE) install; \
	else \
		echo "License setup failed"; \
		exit 1; \
	fi

clean-license: ## Remove development license
	@if [ -f ".replicated/license.env" ]; then \
		. .replicated/license.env && \
		replicated customer rm --customer "$$CUSTOMER_NAME" 2>/dev/null || true; \
	fi
	@rm -rf .replicated/
	@echo "License configuration removed"

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
	rm -f *.tgz

clean-install: clean update-deps install ## Clean rebuild and install

port-forward: ## Port forward to Flipt service
	@echo "Port forwarding to Flipt (http://localhost:8080)..."
	kubectl port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME)-flipt 8080:8080

replicated-lint: ## Lint Replicated KOTS configs
	@echo "Linting KOTS configuration..."
	replicated release lint --yaml-dir replicated/

replicated-create: ## Create a new Replicated release
	@echo "Creating Replicated release..."
	replicated release create --auto --yaml-dir replicated/

preflight: ## Run preflight checks
	@echo "Running preflight checks..."
	kubectl preflight ./replicated/kots-preflight.yaml

support-bundle: ## Generate support bundle
	@echo "Generating support bundle..."
	kubectl support-bundle ./replicated/kots-support-bundle.yaml

check-deps: ## Verify all required tools are installed
	@echo "Checking dependencies..."
	@command -v helm >/dev/null 2>&1 || { echo "helm is not installed"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "kubectl is not installed"; exit 1; }
	@echo "All dependencies satisfied!"

# Development helpers
dev-install: update-deps install ## Update dependencies and install

dev-upgrade: update-deps upgrade ## Update dependencies and upgrade

watch-pods: ## Watch pod status
	kubectl get pods -n $(NAMESPACE) -w
