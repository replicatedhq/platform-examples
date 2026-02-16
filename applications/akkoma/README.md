# Akkoma - Replicated Platform Example

Akkoma is a federated social networking server implementing the ActivityPub protocol (Fediverse). This directory packages the [akkoma-helm](https://github.com/adamancini/akkoma-helm) chart as a Replicated application with KOTS Admin Console support and Embedded Cluster deployment.

## Architecture

The Akkoma deployment consists of:

- **Akkoma** - Elixir/BEAM application serving the ActivityPub API and web frontend
- **PostgreSQL** - Database backend (bundled StatefulSet or external)
- **Storage** - Local PVC or S3-compatible object storage for media uploads
- **Garage** (optional) - Self-hosted S3-compatible storage deployed alongside Akkoma
- **Ingress** - nginx ingress with optional cert-manager TLS

### Embedded Cluster Extensions

When deployed via Embedded Cluster, the following are installed automatically:

| Extension | Version | Namespace |
|-----------|---------|-----------|
| ingress-nginx | 4.14.1 | ingress-nginx |
| cert-manager | v1.19.1 | cert-manager |

## Prerequisites

- [Replicated CLI](https://docs.replicated.com/reference/replicated-cli-installing)
- [Helm](https://helm.sh/docs/intro/install/) v3
- Git (for cloning the chart at build time)
- A Replicated application configured in the vendor portal

## External Chart

Unlike other applications in this repository, the Akkoma Helm chart is **not vendored** in this directory. It lives at [github.com/adamancini/akkoma-helm](https://github.com/adamancini/akkoma-helm) and is cloned at build time by the Makefile.

The `charts/` directory is in `.gitignore`.

## Build and Release

```bash
# Clone the chart, update dependencies, package, and release to Unstable
make release

# Or step by step:
make clone-chart           # Clone/update the akkoma-helm repo
make update-dependencies   # helm dependency update
make package-and-update    # Package .tgz and update chartVersion in kots/
make release               # All of the above + replicated release create

# Pin to a specific branch
make release AKKOMA_CHART_BRANCH=develop

# Lint everything
make lint

# Clean build artifacts
make clean
```

## Configuration Reference

The KOTS Admin Console exposes these configuration groups:

### Instance Settings

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `akkoma_domain` | text | (required) | Public domain for the instance |
| `akkoma_admin_email` | text | (required) | Admin email / Let's Encrypt contact |
| `akkoma_instance_name` | text | | Display name (defaults to domain) |
| `akkoma_description` | text | | Instance description |
| `akkoma_registrations_open` | bool | false | Allow new user registrations |
| `akkoma_character_limit` | text | 5000 | Max characters per post |
| `akkoma_upload_limit` | text | 16000000 | Max upload size in bytes |

### Ingress & TLS

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `ingress_enabled` | bool | true | Create an Ingress resource |
| `ingress_class_name` | text | nginx | IngressClass name |
| `ingress_tls_type` | select | none | TLS mode: none / cert-manager / existing-secret |
| `ingress_tls_secret_name` | text | akkoma-tls | TLS secret name |

### PostgreSQL

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `postgres_type` | select | internal | Internal (bundled) or external database |
| `postgres_database` | text | akkoma | Database name |
| `postgres_username` | text | akkoma | Database username |
| `postgres_storage_size` | text | 10Gi | PVC size (internal only) |
| `postgres_storage_class` | text | | Storage class (internal only) |
| `postgres_external_host` | text | | External host (external only) |
| `postgres_external_port` | text | 5432 | External port (external only) |
| `postgres_external_password_secret` | text | | Secret name for password (external only) |
| `postgres_external_password_key` | text | password | Key in secret (external only) |

### Storage

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `storage_type` | select | local | Local PVC or S3-compatible |
| `storage_uploads_size` | text | 50Gi | Uploads PVC size (local only) |
| `storage_uploads_class` | text | | Storage class (local only) |
| `s3_endpoint` | text | | S3 endpoint (S3 only) |
| `s3_region` | text | us-east-1 | S3 region (S3 only) |
| `s3_bucket` | text | akkoma-uploads | S3 bucket (S3 only) |
| `s3_base_url` | text | | Public media URL (S3 only) |
| `s3_access_key` | password | | Access key (S3 only) |
| `s3_secret_key` | password | | Secret key (S3 only) |

### Garage, Metrics, Network Policies

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `garage_enabled` | bool | false | Deploy Garage for self-hosted S3 |
| `garage_meta_size` | text | 1Gi | Garage metadata volume |
| `garage_data_size` | text | 50Gi | Garage data volume |
| `metrics_enabled` | bool | false | Enable Prometheus metrics |
| `metrics_service_monitor_enabled` | bool | false | Create ServiceMonitor |
| `network_policy_enabled` | bool | false | Enable NetworkPolicy resources |

## Known Limitations

### Air-gap Init Containers

The Akkoma Helm chart uses init containers with hardcoded images that cannot be overridden via values:

- `postgres:15-alpine` - PostgreSQL readiness check
- `alpine:3.23` - Frontend installation

In air-gapped environments, KOTS registry rewriting handles the main Akkoma image, but these init container images must be available in the cluster. Full air-gap support requires upstream chart changes to accept image overrides for init containers.

### ImagePullSecrets

The chart does not currently support `imagePullSecrets` in `values.yaml`. KOTS handles the primary image via registry rewriting, but init container images are not covered.

### ClusterIssuer Lifecycle

The Let's Encrypt ClusterIssuer (`cluster-issuer.yaml`) requires cert-manager to be installed. In Embedded Cluster deployments, cert-manager is installed as an extension. In existing-cluster (non-EC) installs, cert-manager must be pre-installed for the cert-manager TLS option to work.
