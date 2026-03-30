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
4. App slug set as `REPLICATED_APP` (e.g., `export REPLICATED_APP=<your-app-slug>`)
5. API token set as `REPLICATED_API_TOKEN`

## Quick Start

### 1. Add Helm repositories and update dependencies

```bash
cd applications/gitlab
make add-helm-repositories
make update-dependencies
```

### 2. Lint the chart

```bash
make lint
```

### 3. Create a release and promote to Unstable

```bash
export REPLICATED_API_TOKEN=<your-token>
export REPLICATED_APP=<your-app-slug>
make release
```

Or manually:

```bash
helm package charts/gitlab -d kots/
REPLICATED_API_TOKEN=$REPLICATED_API_TOKEN replicated release create \
  --app $REPLICATED_APP \
  --yaml-dir kots \
  --promote Unstable \
  --release-notes "Initial release"
```

### 4. Install with Helm CLI (customer flow)

This is the standard customer install path using the Replicated OCI registry.
See: https://docs.replicated.com/vendor/install-with-helm

**Create a customer** (vendor side):

```bash
replicated customer create \
  --app <your-app-slug> \
  --name my-customer \
  --channel Unstable \
  --type dev \
  --email customer@example.com \
  --expires-in 72h \
  --output json
```

Note the `installationId` from the output -- this is the license ID used for
registry authentication.

**Install** (customer side):

```bash
# 1. Authenticate to Replicated registry
helm registry login registry.replicated.com \
  --username <customer-email> \
  --password <license-id>

# 2. Install from OCI registry
helm install gitlab \
  oci://registry.replicated.com/<your-app-slug>/unstable/gitlab \
  --namespace gitlab \
  --create-namespace \
  --set global.replicated.licenseID=<license-id> \
  -f tests/helm/cmx-deploy-values.yaml \
  --timeout 20m \
  --wait
```

Customers receive `<customer-email>` and `<license-id>` from the vendor when a
customer record is created for them in the Replicated Vendor Portal.

**Important notes:**
- The registry password is the `installationId` (license ID), NOT the customer `id`.
- The OCI URL format is `oci://registry.replicated.com/<app-slug>/<channel>/<chart-name>`.
- The GitLab chart's bundled Bitnami PostgreSQL/Redis images have been removed from
  Docker Hub. You must provide external PostgreSQL 16+ and Redis 7+ services.
  See `tests/helm/cmx-deploy-values.yaml` for an example configuration.

### 5. Deploy with Embedded Cluster

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
