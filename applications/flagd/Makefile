CLUSTER_NAME   ?= flagd-demo
RELEASE_NAME   ?= flagd
CHART_DIR      := charts/flagd
NAMESPACE      ?= default
LOCAL_HTTP_PORT ?= 8016
UPGRADE_VALUES := -f demo-upgrade-values.yaml
SAMPLE_SIZE    ?= 100

# CMX cluster configuration
CMX_DISTRIBUTION ?= k3s
CMX_K8S_VERSION  ?= 1.32.13
CMX_INSTANCE_TYPE ?= r1.small
CMX_NODE_COUNT   ?= 1
CMX_DISK_SIZE    ?= 50
CMX_TTL          ?= 4h
CMX_CLUSTER_NAME ?= flagd-demo

.PHONY: help cluster status checksum pod-age configmap-flags \
        port-forward port-forward-stop \
        eval-flags eval-flag-checkout eval-flag-darkmode eval-flag-maintenance \
        problem problem-step1 problem-step2 problem-step3 problem-teardown \
        solution solution-step1 solution-step2 solution-step3 solution-teardown \
        cmx-cluster-create cmx-cluster-kubeconfig cmx-cluster-list cmx-cluster-rm cmx-clean \
        clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------

cluster: ## Start a minikube cluster
	@if minikube status -p $(CLUSTER_NAME) >/dev/null 2>&1; then \
		echo "Cluster '$(CLUSTER_NAME)' is already running."; \
	else \
		minikube start -p $(CLUSTER_NAME); \
	fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

status: ## Show pods, services, and the configmap
	@echo "=== Pods ==="
	@kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=flagd
	@echo ""
	@echo "=== Service ==="
	@kubectl get svc -n $(NAMESPACE) -l app.kubernetes.io/name=flagd
	@echo ""
	@echo "=== ConfigMap (flags.json) ==="
	@kubectl get configmap $(RELEASE_NAME) -n $(NAMESPACE) -o jsonpath='{.data.flags\.json}' | python3 -m json.tool 2>/dev/null || \
		kubectl get configmap $(RELEASE_NAME) -n $(NAMESPACE) -o jsonpath='{.data.flags\.json}'

checksum: ## Show the checksum/config annotation on the pod (if present)
	@kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=flagd \
		-o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.checksum/config}{"\n"}{end}'

pod-age: ## Show pod names and ages
	@kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=flagd \
		-o custom-columns='NAME:.metadata.name,AGE:.metadata.creationTimestamp,STATUS:.status.phase' --no-headers

configmap-flags: ## Show a summary of all flag defaults from the ConfigMap
	@kubectl get configmap $(RELEASE_NAME) -n $(NAMESPACE) -o jsonpath='{.data.flags\.json}' | \
		python3 -c "\
import sys,json; d=json.load(sys.stdin)['flags']; \
co=d['new-checkout-flow']['targeting']['fractional']; \
print(f'  new-checkout-flow : on={co[0][1]}%  off={co[1][1]}%'); \
print(f'  dark-mode         : {d[\"dark-mode\"][\"defaultVariant\"]}'); \
print(f'  maintenance-mode  : {d[\"maintenance-mode\"][\"defaultVariant\"]}')"

# ---------------------------------------------------------------------------
# Flag evaluation
# ---------------------------------------------------------------------------

port-forward: ## Start port-forward to flagd HTTP API (background)
	@if lsof -i :$(LOCAL_HTTP_PORT) >/dev/null 2>&1; then \
		echo "Port $(LOCAL_HTTP_PORT) already in use (port-forward may already be running)."; \
	else \
		kubectl port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME) $(LOCAL_HTTP_PORT):8016 >/dev/null 2>&1 & \
		sleep 2; \
		echo "Port-forward active: http://localhost:$(LOCAL_HTTP_PORT)"; \
	fi

port-forward-stop: ## Stop the port-forward
	@-pkill -f "kubectl port-forward.*$(LOCAL_HTTP_PORT):8016" 2>/dev/null && \
		echo "Port-forward stopped." || echo "No port-forward running."

eval-flag-checkout: ## Evaluate new-checkout-flow across $(SAMPLE_SIZE) users and show distribution
	@echo "=== new-checkout-flow (sampled across $(SAMPLE_SIZE) users) ==="
	@tmpdir=$$(mktemp -d); \
	for i in $$(seq -w 1 $(SAMPLE_SIZE)); do \
		( curl -s http://localhost:$(LOCAL_HTTP_PORT)/ofrep/v1/evaluate/flags/new-checkout-flow \
			-H 'Content-Type: application/json' \
			-d "{\"context\":{\"targetingKey\":\"user-$$i\"}}" \
			| python3 -c "import sys,json; print(json.load(sys.stdin).get('variant','err'))" \
			> "$$tmpdir/$$i" 2>/dev/null ) & \
	done; \
	wait; \
	on=$$(grep -l '^on$$' "$$tmpdir"/* 2>/dev/null | wc -l | tr -d ' '); \
	off=$$(grep -l '^off$$' "$$tmpdir"/* 2>/dev/null | wc -l | tr -d ' '); \
	total=$$((on+off)); \
	pct=$$((on * 100 / total)); \
	echo "  on:  $$on / $$total  ($$pct%)"; \
	echo "  off: $$off / $$total  ($$((100 - pct))%)"; \
	rm -rf "$$tmpdir"

eval-flag-darkmode: ## Evaluate the dark-mode flag
	@echo "=== dark-mode ==="
	@curl -s http://localhost:$(LOCAL_HTTP_PORT)/ofrep/v1/evaluate/flags/dark-mode \
		-H 'Content-Type: application/json' \
		-d '{"context":{}}' | python3 -m json.tool

eval-flag-maintenance: ## Evaluate the maintenance-mode flag
	@echo "=== maintenance-mode ==="
	@curl -s http://localhost:$(LOCAL_HTTP_PORT)/ofrep/v1/evaluate/flags/maintenance-mode \
		-H 'Content-Type: application/json' \
		-d '{"context":{}}' | python3 -m json.tool

eval-flags: ## Evaluate all flags concurrently
	@$(MAKE) --no-print-directory -j3 _eval-all-checkout _eval-all-darkmode _eval-all-maintenance

_eval-all-checkout:
	@$(MAKE) --no-print-directory eval-flag-checkout

_eval-all-darkmode:
	@$(MAKE) --no-print-directory eval-flag-darkmode

_eval-all-maintenance:
	@$(MAKE) --no-print-directory eval-flag-maintenance

# ===========================================================================
# PROBLEM — without the checksum annotation
#
#   Full run:     make problem
#   Step-by-step: make problem-step1  →  problem-step2  →  problem-step3
#   Cleanup:      make problem-teardown
# ===========================================================================

problem: problem-step1 problem-step2 problem-step3 problem-teardown ## Demo (full run): stale evaluations without checksum

problem-step1: ## Problem 1/3: Deploy flagd WITHOUT checksum, evaluate all flags
	@echo "============================================================"
	@echo " PROBLEM: Pods don't restart when ConfigMap changes"
	@echo "============================================================"
	@echo ""
	@echo "Deploying flagd WITHOUT checksum annotation..."
	helm install $(RELEASE_NAME) $(CHART_DIR) -n $(NAMESPACE) \
		--set flagd.checksumAnnotation=false
	@echo ""
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=flagd -n $(NAMESPACE) --timeout=120s
	@echo ""
	@$(MAKE) --no-print-directory port-forward
	@echo ""
	@echo "------------------------------------------------------------"
	@echo " Initial state"
	@echo "------------------------------------------------------------"
	@$(MAKE) --no-print-directory pod-age
	@echo ""
	@echo "  ConfigMap values:"
	@$(MAKE) --no-print-directory configmap-flags
	@echo ""
	@echo "  Flag evaluations:"
	@$(MAKE) --no-print-directory eval-flags

problem-step2: ## Problem 2/3: Upgrade all flags
	@echo ""
	@echo "------------------------------------------------------------"
	@echo " Upgrade — rollout to 50%, enable dark-mode & maintenance"
	@echo "------------------------------------------------------------"
	@echo ""
	helm upgrade $(RELEASE_NAME) $(CHART_DIR) -n $(NAMESPACE) \
		--set flagd.checksumAnnotation=false \
		$(UPGRADE_VALUES)
	@echo ""
	@sleep 3
	@$(MAKE) --no-print-directory pod-age
	@echo ""
	@echo "  ConfigMap values (updated):"
	@$(MAKE) --no-print-directory configmap-flags

problem-step3: ## Problem 3/3: Evaluate — pod is still serving stale config
	@echo ""
	@echo "------------------------------------------------------------"
	@echo " Compare — ConfigMap vs. what the pod is actually serving"
	@echo "------------------------------------------------------------"
	@echo ""
	@echo "  ConfigMap says:"
	@$(MAKE) --no-print-directory configmap-flags
	@echo ""
	@echo "  Pod is serving:"
	@$(MAKE) --no-print-directory eval-flags
	@echo ""
	@echo "============================================================"
	@echo " RESULT: The ConfigMap was updated, but the pod did NOT"
	@echo " restart. Evaluations are STALE — they don't match the"
	@echo " ConfigMap."
	@echo "============================================================"

problem-teardown: ## Problem: clean up
	@echo ""
	@echo "Cleaning up..."
	@$(MAKE) --no-print-directory port-forward-stop
	helm uninstall $(RELEASE_NAME) -n $(NAMESPACE)
	@echo ""
	@echo "Next: make solution  (or make solution-step1)"

# ===========================================================================
# SOLUTION — with the checksum annotation
#
#   Full run:     make solution
#   Step-by-step: make solution-step1  →  solution-step2  →  solution-step3
#   Cleanup:      make solution-teardown
# ===========================================================================

solution: solution-step1 solution-step2 solution-step3 solution-teardown ## Demo (full run): fresh evaluations with checksum

solution-step1: ## Solution 1/3: Deploy flagd WITH checksum, evaluate all flags
	@echo "============================================================"
	@echo " SOLUTION: checksum annotation triggers rolling update"
	@echo "============================================================"
	@echo ""
	@echo "Deploying flagd WITH checksum annotation..."
	helm install $(RELEASE_NAME) $(CHART_DIR) -n $(NAMESPACE)
	@echo ""
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=flagd -n $(NAMESPACE) --timeout=120s
	@echo ""
	@$(MAKE) --no-print-directory port-forward
	@echo ""
	@echo "------------------------------------------------------------"
	@echo " Initial state"
	@echo "------------------------------------------------------------"
	@$(MAKE) --no-print-directory pod-age
	@$(MAKE) --no-print-directory checksum
	@echo ""
	@echo "  ConfigMap values:"
	@$(MAKE) --no-print-directory configmap-flags
	@echo ""
	@echo "  Flag evaluations:"
	@$(MAKE) --no-print-directory eval-flags

solution-step2: ## Solution 2/3: Upgrade all flags — rolling update occurs
	@echo ""
	@echo "------------------------------------------------------------"
	@echo " Upgrade — rollout to 50%, enable dark-mode & maintenance"
	@echo "------------------------------------------------------------"
	@echo ""
	@$(MAKE) --no-print-directory port-forward-stop
	helm upgrade $(RELEASE_NAME) $(CHART_DIR) -n $(NAMESPACE) \
		$(UPGRADE_VALUES)
	@echo ""
	@echo "Waiting for rolling update..."
	@kubectl rollout status deployment/$(RELEASE_NAME) -n $(NAMESPACE)
	@echo ""
	@$(MAKE) --no-print-directory port-forward
	@echo ""
	@$(MAKE) --no-print-directory pod-age
	@$(MAKE) --no-print-directory checksum
	@echo ""
	@echo "  ConfigMap values (updated):"
	@$(MAKE) --no-print-directory configmap-flags

solution-step3: ## Solution 3/3: Evaluate — pod is serving fresh config
	@echo ""
	@echo "------------------------------------------------------------"
	@echo " Compare — ConfigMap vs. what the pod is actually serving"
	@echo "------------------------------------------------------------"
	@echo ""
	@echo "  ConfigMap says:"
	@$(MAKE) --no-print-directory configmap-flags
	@echo ""
	@echo "  Pod is serving:"
	@$(MAKE) --no-print-directory eval-flags
	@echo ""
	@echo "============================================================"
	@echo " RESULT: The checksum changed, a rolling update occurred,"
	@echo " and evaluations MATCH the ConfigMap."
	@echo "============================================================"

solution-teardown: ## Solution: clean up
	@echo ""
	@echo "Cleaning up..."
	@$(MAKE) --no-print-directory port-forward-stop
	helm uninstall $(RELEASE_NAME) -n $(NAMESPACE)

# ===========================================================================
# Compatibility Matrix (CMX) — Replicated platform testing
# ===========================================================================

cmx-cluster-create: ## Create a CMX cluster
	@echo "Creating CMX cluster: $(CMX_CLUSTER_NAME) ($(CMX_DISTRIBUTION) $(CMX_K8S_VERSION))..."
	replicated cluster create \
		--name "$(CMX_CLUSTER_NAME)" \
		--distribution "$(CMX_DISTRIBUTION)" \
		--version "$(CMX_K8S_VERSION)" \
		--disk "$(CMX_DISK_SIZE)" \
		--instance-type "$(CMX_INSTANCE_TYPE)" \
		--nodes "$(CMX_NODE_COUNT)" \
		--ttl "$(CMX_TTL)"
	@echo ""
	@echo "Cluster creation started. Run 'make cmx-cluster-list' to check status."
	@echo "Once 'running', run: make cmx-cluster-kubeconfig"

cmx-cluster-kubeconfig: ## Fetch and activate kubeconfig for the CMX cluster
	replicated cluster kubeconfig --name "$(CMX_CLUSTER_NAME)"
	@echo ""
	@echo "Kubeconfig active. Verify with: kubectl get nodes"

cmx-cluster-list: ## List CMX clusters
	replicated cluster ls

cmx-cluster-rm: ## Delete the CMX cluster
	CLUSTER_ID=$$(replicated cluster ls --output json | jq -r '.[] | select(.name == "$(CMX_CLUSTER_NAME)") | .id'); \
	if [ -z "$$CLUSTER_ID" ]; then \
		echo "Cluster not found: $(CMX_CLUSTER_NAME)"; \
		exit 1; \
	fi; \
	replicated cluster rm "$$CLUSTER_ID"
	rm -f ~/.kube/$(CMX_CLUSTER_NAME)-config
	@echo "Cluster deleted."

cmx-clean: ## Uninstall the chart and delete the CMX cluster
	-@$(MAKE) --no-print-directory port-forward-stop
	-helm uninstall $(RELEASE_NAME) -n $(NAMESPACE) 2>/dev/null
	@$(MAKE) --no-print-directory cmx-cluster-rm

# ---------------------------------------------------------------------------
# Cleanup (local minikube)
# ---------------------------------------------------------------------------

clean: ## Uninstall the chart and delete the minikube cluster
	-@$(MAKE) --no-print-directory port-forward-stop
	-helm uninstall $(RELEASE_NAME) -n $(NAMESPACE) 2>/dev/null
	-minikube delete -p $(CLUSTER_NAME) 2>/dev/null
