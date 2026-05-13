.PHONY: add-helm-repositories update-dependencies lint package release \
        cluster-create cluster-delete setup-deps teardown-deps install uninstall

PG_PASSWORD    ?= gitlab-pg-pass
REDIS_PASSWORD ?= gitlab-redis-pass

CHART_DIR        := charts/gitlab
CLUSTER_NAME     ?= gitlab-cmx
CMX_DISTRIBUTION ?= k3s
CMX_VERSION      ?= 1.32
CMX_INSTANCE     ?= r1.xlarge
CMX_DISK         ?= 100
CMX_TTL          ?= 4h
CLUSTER_ID_FILE  := .cluster-id

add-helm-repositories:
	helm repo add gitlab https://charts.gitlab.io/
	helm repo update

update-dependencies:
	helm dependency update $(CHART_DIR)

lint:
	helm lint $(CHART_DIR)
	helm template gitlab $(CHART_DIR) -f tests/helm/ci-values.yaml > /dev/null

package: update-dependencies
	helm package $(CHART_DIR) -d kots/

release: package
	REPLICATED_API_TOKEN=$(REPLICATED_API_TOKEN) replicated release create \
		--app $(REPLICATED_APP) \
		--yaml-dir kots \
		--promote Unstable \
		--release-notes "Release via Makefile"

# CMX cluster management
cluster-create:
	@echo "Creating CMX cluster '$(CLUSTER_NAME)'..."
	replicated cluster create \
		--distribution $(CMX_DISTRIBUTION) \
		--version $(CMX_VERSION) \
		--instance-type $(CMX_INSTANCE) \
		--disk $(CMX_DISK) \
		--ttl $(CMX_TTL) \
		--name $(CLUSTER_NAME) \
		--wait 10m \
		--output json | jq -r '.id' > $(CLUSTER_ID_FILE)
	replicated cluster kubeconfig $$(cat $(CLUSTER_ID_FILE))
	@echo "Cluster ready. ID: $$(cat $(CLUSTER_ID_FILE))"

cluster-delete:
	@test -f $(CLUSTER_ID_FILE) || (echo "No $(CLUSTER_ID_FILE) found. Run 'make cluster-create' first."; exit 1)
	replicated cluster rm $$(cat $(CLUSTER_ID_FILE))
	rm -f $(CLUSTER_ID_FILE)

# In-cluster PostgreSQL and Redis for CMX testing (not for production)
setup-deps:
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo update
	kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install postgresql bitnami/postgresql \
		--namespace gitlab \
		--set fullnameOverride=external-postgresql \
		--set auth.username=gitlab \
		--set auth.password=$(PG_PASSWORD) \
		--set auth.database=gitlabhq_production \
		--set primary.resourcesPreset=none \
		--set primary.resources.requests.memory=1Gi \
		--set primary.resources.limits.memory=2Gi \
		--wait
	helm upgrade --install redis bitnami/redis \
		--namespace gitlab \
		--set fullnameOverride=external-redis \
		--set architecture=standalone \
		--set auth.password=$(REDIS_PASSWORD) \
		--wait
	kubectl create secret generic gitlab-external-pg-password \
		--from-literal=password=$(PG_PASSWORD) \
		--namespace gitlab \
		--dry-run=client -o yaml | kubectl apply -f -
	kubectl create secret generic gitlab-external-redis-password \
		--from-literal=redis-password=$(REDIS_PASSWORD) \
		--namespace gitlab \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "Granting superuser to gitlab DB user so migrations can CREATE EXTENSION..."
	kubectl exec -n gitlab pod/external-postgresql-0 -- \
		env PGPASSWORD=$$(kubectl get secret external-postgresql -n gitlab \
			-o jsonpath='{.data.postgres-password}' | base64 -d) \
		psql -U postgres -c "ALTER USER gitlab SUPERUSER;"

teardown-deps:
	helm uninstall postgresql --namespace gitlab --ignore-not-found
	helm uninstall redis --namespace gitlab --ignore-not-found

# Helm install / uninstall (customer flow via Replicated OCI registry)
install:
	@test -n "$(REPLICATED_CUSTOMER_EMAIL)" || (echo "REPLICATED_CUSTOMER_EMAIL is not set"; exit 1)
	@test -n "$(REPLICATED_LICENSE_ID)" || (echo "REPLICATED_LICENSE_ID is not set"; exit 1)
	helm registry login registry.replicated.com \
		--username $(REPLICATED_CUSTOMER_EMAIL) \
		--password $(REPLICATED_LICENSE_ID)
	helm install gitlab \
		oci://registry.replicated.com/$(REPLICATED_APP)/unstable/gitlab \
		--namespace gitlab \
		--create-namespace \
		--set global.replicated.licenseID=$(REPLICATED_LICENSE_ID) \
		-f tests/helm/cmx-deploy-values.yaml \
		--timeout 20m \
		--wait

uninstall:
	helm uninstall gitlab --namespace gitlab
	kubectl delete namespace gitlab --ignore-not-found
