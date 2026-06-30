# GitLab Platform Example

This example demonstrates how to deploy [GitLab](https://gitlab.com) — The One DevSecOps Platform — using Replicated's [Embedded Cluster](https://docs.replicated.com/vendor/embedded-overview) and [Compatibility Matrix](https://docs.replicated.com/vendor/testing-about).

## Architecture Overview

GitLab is a complex, multi-component application. This example uses the [official GitLab Helm chart](https://docs.gitlab.com/charts/) wrapped with the Replicated SDK.

### Components

| Component | Purpose | Default |
|-----------|---------|---------|
| GitLab Webservice | Web UI and API | Bundled |
| GitLab Sidekiq | Background jobs | Bundled |
| GitLab KAS | Kubernetes Agent Server | Bundled |
| GitLab Shell | SSH access | Bundled |
| PostgreSQL | Primary database | Bundled (eval) |
| Redis | Cache, sessions, queues | Bundled (eval) |
| MinIO | Object storage | Bundled (eval) |
| Registry | Container registry | Bundled |
| NGINX Ingress | Ingress controller | Via EC extension |
| cert-manager | TLS certificates | Via EC extension |

### Production Considerations

> **WARNING**: The bundled PostgreSQL, Redis, and MinIO are **deprecated** and will be
> removed in GitLab 19.0. For production deployments, use external services.

**Production requirements:**
- External PostgreSQL 16+ with extensions: `amcheck`, `pg_trgm`, `btree_gist`
- External Redis/Valkey (HA configuration recommended)
- External S3-compatible object storage (many buckets required)
- Minimum 2 nodes: 8 vCPU total, 30 GB RAM
- **Gitaly cannot run in Kubernetes** for production — must use VMs/bare metal

**Evaluation minimum:** 4 vCPU, 12 GB RAM, 100 GB disk

## Prerequisites

1. [Replicated Vendor Portal Account](https://vendor.replicated.com/signup)
2. [Replicated CLI](https://docs.replicated.com/reference/replicated-cli-installing)
3. CMX Credits (minimum: `r1.large` or equivalent)
4. Environment variables set (see [direnv setup](#environment-setup-direnv) below)

## Environment Setup (direnv)

Copy the example env file, fill in your values, then allow direnv to load it:

```bash
cp .envrc.example .envrc
# Edit .envrc with your REPLICATED_API_TOKEN and REPLICATED_APP
direnv allow
```

`.envrc` is git-ignored. If you don't use direnv, export the variables manually:

```bash
export REPLICATED_API_TOKEN=<your-token>
export REPLICATED_APP=<your-app-slug>
```

Install direnv: https://direnv.net/docs/installation.html

## Quick Start

### 1. Add Helm repositories and update dependencies

```bash
cd applications/gitlab
make add-helm-repositories
make update-dependencies
```

### 2. Lint the chart

```bash
helm lint charts/gitlab
helm template gitlab charts/gitlab -f tests/helm/ci-values.yaml > /dev/null
```

Or via `make lint`.

### 3. Create a release and promote to Unstable

Package the chart and push a release to the [Replicated Vendor Portal](https://vendor.replicated.com):

```bash
helm package charts/gitlab -d kots/

replicated release create \
  --app $REPLICATED_APP \
  --yaml-dir kots \
  --promote Unstable \
  --release-notes "Initial release"
```

Or via `make release`.

### 4. Create a customer and set license env vars

```bash
replicated customer create \
  --app $REPLICATED_APP \
  --name my-customer \
  --channel Unstable \
  --type dev \
  --email customer@example.com \
  --expires-in 72h \
  --output json
```

Note the `installationId` from the output — this is the license ID used for
registry authentication. Add it to your `.envrc`:

```bash
export REPLICATED_LICENSE_ID=<installationId>
export REPLICATED_CUSTOMER_EMAIL=customer@example.com
direnv allow
```

### 5. Create a CMX cluster

Use the [Replicated Compatibility Matrix](https://docs.replicated.com/vendor/testing-about) to provision a cluster:

```bash
replicated cluster create \
  --distribution k3s \
  --version 1.32 \
  --instance-type r1.xlarge \
  --disk 100 \
  --ttl 4h \
  --name gitlab-cmx \
  --wait 10m \
  --output json | jq -r '.id' > .cluster-id

replicated cluster kubeconfig $(cat .cluster-id)
kubectl cluster-info   # verify connectivity
```

Or via `make cluster-create` (uses the same commands with overridable defaults).

### 6. Deploy in-cluster PostgreSQL and Redis

`tests/helm/cmx-deploy-values.yaml` requires external PostgreSQL and Redis — the GitLab chart's bundled Bitnami images were removed from Docker Hub. Deploy them into the cluster using the Bitnami Helm charts before installing GitLab:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Deploy PostgreSQL 16 with the service name GitLab expects
helm upgrade --install postgresql bitnami/postgresql \
  --namespace gitlab \
  --create-namespace \
  --set fullnameOverride=external-postgresql \
  --set auth.username=gitlab \
  --set auth.password=gitlab-pg-pass \
  --set auth.database=gitlabhq_production \
  --set primary.resourcesPreset=none \
  --set primary.resources.requests.memory=1Gi \
  --set primary.resources.limits.memory=2Gi \
  --wait

# Deploy Redis 7 (standalone)
# The Bitnami chart always creates the service as <fullnameOverride>-master,
# which matches the redis.host value in cmx-deploy-values.yaml (external-redis-master)
helm upgrade --install redis bitnami/redis \
  --namespace gitlab \
  --set fullnameOverride=external-redis \
  --set architecture=standalone \
  --set auth.password=gitlab-redis-pass \
  --wait

# Create the secrets GitLab reads for credentials
kubectl create secret generic gitlab-external-pg-password \
  --from-literal=password=gitlab-pg-pass \
  --namespace gitlab

kubectl create secret generic gitlab-external-redis-password \
  --from-literal=redis-password=gitlab-redis-pass \
  --namespace gitlab

# Grant superuser to the gitlab DB user so migrations can CREATE EXTENSION
# (pg_trgm, btree_gist, amcheck — required by GitLab migrations)
# The Bitnami chart creates a non-superuser by default; the postgres superuser
# password is stored in the chart-generated secret.
kubectl exec -n gitlab pod/external-postgresql-0 -- \
  env PGPASSWORD=$(kubectl get secret external-postgresql -n gitlab \
    -o jsonpath='{.data.postgres-password}' | base64 -d) \
  psql -U postgres -c "ALTER USER gitlab SUPERUSER;"
```

> - `fullnameOverride` ensures the Kubernetes service names match `psql.host` and `redis.host` in `cmx-deploy-values.yaml`.
> - The superuser grant is required because GitLab migrations run `CREATE EXTENSION` statements, which require superuser in PostgreSQL.

Or via `make setup-deps` (uses the same commands; override passwords with `PG_PASSWORD` and `REDIS_PASSWORD`).

### 7. Install GitLab

Authenticate to the Replicated OCI registry and install:

```bash
helm registry login registry.replicated.com \
  --username $REPLICATED_CUSTOMER_EMAIL \
  --password $REPLICATED_LICENSE_ID

helm install gitlab \
  oci://registry.replicated.com/$REPLICATED_APP/unstable/gitlab \
  --namespace gitlab \
  --create-namespace \
  --set global.replicated.licenseID=$REPLICATED_LICENSE_ID \
  -f tests/helm/cmx-deploy-values.yaml \
  --timeout 20m \
  --wait
```

Or via `make install`.

### 8. Access the GitLab UI

The chart deploys an nginx ingress controller with `gitlab.example.com` as the domain (see `tests/helm/cmx-deploy-values.yaml`). Port-forward the ingress controller and add a local hosts entry to access it:

```bash
# Add a hosts entry (requires sudo)
echo "127.0.0.1 gitlab.example.com" | sudo tee -a /etc/hosts

# Port-forward the nginx ingress controller
kubectl port-forward svc/gitlab-nginx-ingress-controller 8080:80 -n gitlab
```

Open http://gitlab.example.com:8080 in your browser.

To get the initial root password:

```bash
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab \
  -o jsonpath='{.data.password}' | base64 --decode
```

Sign in as `root` with that password.

### 9. Clean up

```bash
helm uninstall gitlab --namespace gitlab
helm uninstall postgresql --namespace gitlab
helm uninstall redis --namespace gitlab
kubectl delete namespace gitlab --ignore-not-found

replicated cluster rm $(cat .cluster-id)
rm .cluster-id
```

Or via `make uninstall && make teardown-deps && make cluster-delete`.

### Deploy with Embedded Cluster

Create a customer and download a license, then:

```bash
replicated cluster create \
  --distribution embedded-cluster \
  --instance-type r1.xlarge \
  --disk 100 \
  --license-id <license-id> \
  --ttl 4h \
  --name gitlab-test

replicated cluster shell <cluster-id>
# Inside the shell:
kubectl port-forward svc/kotsadm 3000:3000 -n kotsadm
```

Navigate to `http://localhost:3000` and configure GitLab via the KOTS admin console.

**Important notes:**
- The registry password is the `installationId` (license ID), NOT the customer `id`.
- The OCI URL format is `oci://registry.replicated.com/<app-slug>/<channel>/<chart-name>`.
- The GitLab chart's bundled Bitnami PostgreSQL/Redis images have been removed from
  Docker Hub. You must provide external PostgreSQL 16+ and Redis 7+ services.
  See `tests/helm/cmx-deploy-values.yaml` for an example configuration.

## Directory Structure

```
applications/gitlab/
├── charts/
│   └── gitlab/
│       ├── Chart.yaml          # Wrapper chart with SDK + upstream gitlab subchart
│       ├── Chart.lock          # Locked dependency versions
│       ├── values.yaml         # Default values with global.replicated block
│       ├── replicated-app.yaml # Replicated Application CRD
│       └── templates/          # Custom templates (empty — uses subchart)
├── kots/
│   ├── kots-app.yaml           # KOTS Application manifest
│   ├── kots-config.yaml        # User-facing configuration options
│   ├── gitlab-chart.yaml       # HelmChart mapping config → helm values
│   ├── ec.yaml                 # Embedded Cluster extensions
│   └── k8s-app.yaml            # Kubernetes Application CRD
├── tests/
│   └── helm/
│       ├── ci-values.yaml          # Minimal values for CI lint/template checks
│       └── cmx-deploy-values.yaml  # Values for CMX cluster deployment (external PG + Redis)
├── Makefile
└── README.md
```

## Known Limitations

See [ONBOARDING-GAPS.md](../../ONBOARDING-GAPS.md) for gaps and friction discovered during onboarding.

- **CMX validation passed**: Helm CLI customer install validated via OCI registry on k3s 1.32 (r1.xlarge). All pods healthy. Replicated SDK running.
- **Bundled Bitnami images removed**: The GitLab chart's bundled PostgreSQL and Redis depend on Bitnami Docker Hub images that have been removed. You MUST provide external PostgreSQL and Redis. See `tests/helm/cmx-deploy-values.yaml`.
- **Gitaly in K8s**: The bundled evaluation mode runs Gitaly in Kubernetes, which is not supported for production. A cloud-native hybrid architecture (stateless K8s + external stateful services) is recommended for production.
- **Resource requirements**: GitLab is significantly more resource-intensive than other examples in this repo. Minimum eval cluster: 4 vCPU, 12 GB RAM.

## References

- [GitLab Helm chart docs](https://docs.gitlab.com/charts/)
- [GitLab chart repository](https://gitlab.com/gitlab-org/charts/gitlab)
- [Replicated SDK docs](https://docs.replicated.com/vendor/replicated-sdk-installing)
- [Embedded Cluster docs](https://docs.replicated.com/vendor/embedded-overview)
