# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this directory.

## Repository Context

**This is part of a monorepo**: `replicatedhq/platform-examples` contains multiple independent application examples in the `applications/` directory. Each application is self-contained with its own build configuration, dependencies, and release workflow.

**Working directory scope**: All operations should be contained within `/applications/storagebox/`. Do not assume VM testing targets, CI/CD pipelines, or other tooling exists at this directory level unless explicitly documented here.

**Parent repository**: The monorepo may have shared documentation or patterns in the root, but this application operates independently.

## Project Overview

Storagebox is a Replicated Embedded Cluster (EC) application that bundles multiple storage backends into a single deployable unit. It provides:

- **Apache Cassandra** - NoSQL database via Bitnami Helm chart
- **PostgreSQL** - Relational database via CloudnativePG Operator
- **MinIO** - S3-compatible object storage via MinIO Operator
- **NFS Server** - Network file system via Obéone Helm chart

This is designed for EC deployments where cluster-scope operators (MinIO, CloudnativePG) are installed during the EC lifecycle, not by the Storagebox chart itself.

## Build and Release Commands

### Build Commands
```bash
# Update Helm chart dependencies
make update-dependencies

# Package charts and update version references in KOTS manifests
make package-and-update

# Clean build artifacts (.tgz files and tmpcharts directories)
make clean

# Add required Helm repositories
make add-helm-repositories

# Create a Replicated release and promote to Unstable channel
make release

# Show all available commands
make help
```

### Deployment Commands

#### Cluster Management
```bash
# Create a single-node test cluster (default: k3s 1.31)
make cluster-create

# Create a cluster with custom settings
make cluster-create CLUSTER_NAME=my-test DISTRIBUTION=k3s K8S_VERSION=1.31

# List all active clusters
make cluster-list

# Get kubeconfig for a cluster
make cluster-kubeconfig CLUSTER_NAME=my-test

# Check cluster status and pods
make cluster-status CLUSTER_NAME=my-test

# Delete a cluster
make cluster-rm CLUSTER_NAME=my-test
```

#### Application Deployment
```bash
# Deploy storagebox to a cluster
make deploy CLUSTER_NAME=my-test CHANNEL=test-v018-k8s131

# Check deployment status
make deploy-status CLUSTER_NAME=my-test

# View pod logs
make deploy-logs CLUSTER_NAME=my-test

# View specific pod logs
make deploy-logs CLUSTER_NAME=my-test POD=cassandra-0
```

#### Complete Test Workflow
```bash
# Run full test cycle: build, release, create cluster, get kubeconfig
make test-cycle

# Run test cycle with custom channel
make test-cycle CHANNEL=test-v018-k8s131

# Follow the printed instructions to deploy and test
```

### Configuration Variables

All commands support these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `CLUSTER_NAME` | storagebox-test-\<timestamp\> | Cluster name |
| `CLUSTER_PREFIX` | storagebox | Cluster name prefix for test-cycle |
| `CUSTOMER_NAME` | current git branch | Customer name for EC testing |
| `CHANNEL` | test-v018-k8s131 | Release channel |
| `DISTRIBUTION` | k3s | Kubernetes distribution |
| `K8S_VERSION` | 1.31 | Kubernetes version |
| `INSTANCE_TYPE` | r1.medium | VM instance type |
| `NODE_COUNT` | 1 | Number of nodes (single-node default) |
| `DISK_SIZE` | 50 | Disk size in GB |
| `TTL` | 4h | Cluster time-to-live |

## Project Architecture

### Directory Structure

```
charts/storagebox/          # Main Helm chart
├── Chart.yaml              # Dependencies: cassandra, nfs-server, tenant (MinIO), replicated
├── values.yaml             # Default values for all components (65K+ lines)
├── templates/              # Custom templates for Storagebox-specific resources
│   ├── postgres-db.yaml    # CloudnativePG Cluster CR
│   ├── postgres-*.yaml     # Postgres secrets and services
│   ├── cassandra-*.yaml    # Cassandra TLS and credentials
│   └── replicated-*.yaml   # Preflight checks and support bundles

kots/                       # KOTS/Replicated deployment manifests
├── ec.yaml                 # Embedded Cluster config - installs operators
├── kots-config.yaml        # Admin console configuration UI
├── storagebox-chart.yaml   # HelmChart CR with KOTS template functions
├── backup.yaml             # Velero backup configuration
└── kots-*.yaml             # App metadata, preflights, support bundles
```

### Key Architecture Patterns

**Operator Dependencies**: The EC config (`kots/ec.yaml`) installs four Helm charts as cluster extensions:
- CloudnativePG operator (namespace: cnpg)
- MinIO operator (namespace: minio)
- cert-manager (namespace: cert-manager)
- ingress-nginx (namespace: ingress-nginx)

**Component Enable/Disable**: Each storage backend can be toggled via:
- Helm values: `cassandra.enabled`, `nfs-server.enabled`, `tenant.enabled`, `postgres.embedded.enabled`
- KOTS config: Maps admin console settings to Helm values using `repl{{ ConfigOption "..." }}` template functions

**TLS Configuration**: Cassandra supports three TLS modes configured via KOTS:
- No TLS
- Auto-generated self-signed certificates
- External CA with user-provided certificates

### Helm Chart Dependencies

The storagebox chart pulls these subcharts (see `charts/storagebox/charts/`):
- `cassandra` (Bitnami) - version ~12.3.11
- `nfs-server` (Obéone) - version ~1.1.2
- `tenant` (MinIO) - version 7.1.1
- `replicated` (Replicated SDK) - version ~1.12.2

### KOTS Template Functions

The `kots/storagebox-chart.yaml` uses Replicated template functions extensively:
- `ConfigOption` / `ConfigOptionEquals` - Read admin console config values
- `HasLocalRegistry` / `LocalRegistryHost` - Air-gap registry support
- `optionalValues` - Conditional value overrides based on config selections

## Version Management

Chart version is tracked in `charts/storagebox/Chart.yaml`. The Makefile automatically:
1. Extracts the version during `make package-and-update`
2. Updates `chartVersion` in `kots/storagebox-chart.yaml`
3. Uses this version for `replicated release create`

## Development Guidelines

### **CRITICAL: The Four-Way Contract**

**This is MANDATORY for all work in this repository, by the main Claude process and all subagents.**

A complex contract must be maintained between four configuration sources. Breaking this contract will cause deployment failures, CI/CD failures, and runtime configuration errors.

#### The Contract

```
development-values.yaml <-> KOTS Config <-> KOTS HelmChart <-> charts/values.yaml
        (1)                     (2)              (3)                   (4)
```

1. **`development-values.yaml`** (at repo root)
   - Kind: `ConfigValues` (kots.io/v1beta1)
   - Purpose: Represents KOTS Config values for headless installations and CI/CD
   - Contains: Default values that would be generated from KOTS Config screen
   - Required: Must exist and stay synchronized with KOTS Config defaults

2. **`kots/kots-config.yaml`**
   - Kind: `Config` (kots.io/v1beta1)
   - Purpose: Defines the Admin Console configuration UI
   - Contains: User-facing config items (text fields, booleans, selects, files)
   - Required: All config items must have defaults that match development-values.yaml

3. **`kots/storagebox-chart.yaml`**
   - Kind: `HelmChart` (kots.io/v1beta2)
   - Purpose: Source of truth for Helm chart values in KOTS deployment
   - Contains: Values with `repl{{ ConfigOption "..." }}` template functions
   - Required: Must accurately represent the structure of `charts/storagebox/values.yaml`
   - **Critical**: Any change to chart values schema MUST be reflected here

4. **`charts/storagebox/values.yaml`**
   - Purpose: Base Helm chart values schema
   - Contains: Default values for all Helm chart parameters
   - Required: Structure must match what HelmChart kind expects

#### Contract Rules

**Rule 1: Chart Values Changes Require HelmChart Updates**
When you modify `charts/storagebox/values.yaml`:
- You MUST update `kots/storagebox-chart.yaml` to reflect the new structure
- You MUST update `kots/kots-config.yaml` if user input is required
- You MUST update `development-values.yaml` with appropriate ConfigValue defaults

**Rule 2: KOTS Config Changes Require Full Sync**
When you modify `kots/kots-config.yaml`:
- You MUST update `development-values.yaml` with new config item defaults
- You MUST update `kots/storagebox-chart.yaml` to use the new ConfigOption
- You MUST verify the chart values.yaml supports the change

**Rule 3: Development Values Must Match Config Defaults**
`development-values.yaml` must contain:
- Every config item from `kots-config.yaml`
- Default values that match the `default:` field in kots-config.yaml
- Structure that allows headless installation via `kubectl kots install --config-values`

**Rule 4: HelmChart is Source of Truth**
The `kots/storagebox-chart.yaml` file is the authoritative source for:
- What values the Helm chart receives during KOTS installation
- How KOTS Config options map to Helm values
- What structure the chart must support

#### Prior Art Reference

See: `/Users/ada/src/github.com/progress-platform-services/chef-replicated/chef-360`
- `development-config-values.yaml` - Example ConfigValues structure
- `manifests/kots-config.yaml` - Example Config with extensive options
- `manifests/kots-helm-chart.yaml` - Example HelmChart with complex mappings

#### Validation Checklist

Before committing any configuration changes, verify:

- [ ] `development-values.yaml` exists and contains all config items
- [ ] All KOTS Config items have defaults matching development-values.yaml
- [ ] All `repl{{ ConfigOption "..." }}` references exist in kots-config.yaml
- [ ] HelmChart values structure matches charts/values.yaml
- [ ] Run `make validate-config` to check contract integrity
- [ ] Test with `make test-cycle` using development-values.yaml

#### Example: Adding a New Configuration

When adding a new config option (e.g., Cassandra replication factor):

**1. Update `kots/kots-config.yaml`:**
```yaml
- name: cassandra_replication_factor
  title: Cassandra Replication Factor
  type: text
  default: "3"
  required: true
```

**2. Update `kots/storagebox-chart.yaml`:**
```yaml
cassandra:
  replicaCount: repl{{ ConfigOption "cassandra_replication_factor" }}
```

**3. Update `development-values.yaml`:**
```yaml
cassandra_replication_factor:
  default: "3"
  value: "3"
```

**4. Verify `charts/storagebox/values.yaml` supports it:**
```yaml
cassandra:
  replicaCount: 3
```

### Project Hygiene

**Version synchronization**: When updating Helm chart dependencies:
1. Update versions in `charts/storagebox/Chart.yaml`
2. Update corresponding operator versions in `kots/ec.yaml` (MinIO operator must match MinIO tenant version)
3. Increment chart version in `Chart.yaml`
4. Run `make update-dependencies` to fetch new charts
5. Run `make package-and-update` to package and update references
6. Update this CLAUDE.md to reflect current versions

**Dependency alignment**:
- MinIO operator (in `kots/ec.yaml`) MUST match MinIO tenant chart version (in `Chart.yaml`)
- CloudnativePG operator provides the CRD for PostgreSQL clusters defined in chart templates
- cert-manager and ingress-nginx are cluster-wide infrastructure components

**Testing before release**:
- Run `helm lint ./charts/storagebox` to catch chart issues
- Run `replicated release lint --yaml-dir ./kots` to catch KOTS manifest issues
- Test template rendering with `helm template storagebox ./charts/storagebox --debug`
- Create test releases in dedicated channels (e.g., `test-v0.17.0`) before promoting to Stable/Beta

**Channel management**:
- Use descriptive channel names for testing: `test-v{version}`, `debug-{feature}`, etc.
- Do not promote to Stable/Beta without thorough testing
- Default `make release` promotes to Unstable channel

### Embedded Cluster VM Testing

**IMPORTANT**: All VM testing uses CMX (Compatibility Matrix) VMs only. Never consider cloud resources.

The Makefile provides comprehensive Embedded Cluster testing workflows with proper customer/license management.

#### Customer Management Workflow

**Key Concepts:**
- Each customer is assigned to a single channel
- EC binary downloads require a customer's license ID
- For feature branch testing, create a customer with the same name as your git branch
- Download URL pattern: `https://app.xyyzx.net/embedded/storagebox/{channel}`
- Authorization header uses the customer's license ID

**Customer Management Commands:**
```bash
# List all customers
make customer-list

# Create a new customer assigned to a channel
make customer-create CUSTOMER_NAME=my-feature-branch CHANNEL=test-my-feature

# Show customer details (ID, license ID, channel)
make customer-info CUSTOMER_NAME=my-feature-branch

# Create customer if it doesn't exist (recommended)
make customer-ensure CUSTOMER_NAME=my-feature-branch CHANNEL=test-my-feature
```

#### Automated EC Test Cycle

The fastest way to set up an EC test environment:

```bash
# Complete automated workflow (customer + VM + download + expose)
make vm-ec-test-cycle CUSTOMER_NAME=my-feature CHANNEL=test-my-feature CLUSTER_PREFIX=my-test

# Then install (UI or headless mode)
make vm-ec-install CLUSTER_PREFIX=my-test CUSTOMER_NAME=my-feature
# OR
make vm-ec-install-headless CLUSTER_PREFIX=my-test CUSTOMER_NAME=my-feature

# Cleanup when done
make vm-cleanup CLUSTER_PREFIX=my-test
```

#### Manual Step-by-Step EC Testing

For more control over the testing process:

**Step 1: Ensure customer exists**
```bash
# Uses current git branch name by default
make customer-ensure CUSTOMER_NAME=$(git rev-parse --abbrev-ref HEAD) CHANNEL=test-my-feature
```

**Step 2: Create CMX VM cluster**
```bash
# Single-node cluster
make vm-1node CLUSTER_PREFIX=my-test

# Three-node HA cluster
make vm-3node CLUSTER_PREFIX=my-test
```

**Step 3: Download EC binary**
```bash
# Downloads to all VMs using customer's license ID
make vm-download-ec CLUSTER_PREFIX=my-test CUSTOMER_NAME=my-feature

# The target will:
# - Fetch customer ID by name
# - Get the customer's license ID
# - Determine the customer's assigned channel
# - Download from: https://app.xyyzx.net/embedded/storagebox/{channel}
# - Use Authorization: {licenseID} header
# - Extract and prepare binary on all nodes
```

**Step 4: Expose admin console port**
```bash
make vm-expose-ports CLUSTER_PREFIX=my-test
```

**Step 5: Install Embedded Cluster**
```bash
# UI mode (configure via admin console)
make vm-ec-install CLUSTER_PREFIX=my-test CUSTOMER_NAME=my-feature

# Headless mode (uses development-values.yaml)
make vm-ec-install-headless CLUSTER_PREFIX=my-test CUSTOMER_NAME=my-feature
```

**Step 6: Cleanup**
```bash
# Delete all VMs for the cluster
make vm-cleanup CLUSTER_PREFIX=my-test
```

#### Additional VM Management Commands

```bash
# List all CMX VMs
make vm-list

# Show status for specific cluster
make vm-status CLUSTER_PREFIX=my-test

# Copy license manually (usually automatic)
make vm-copy-license CLUSTER_PREFIX=my-test CUSTOMER_NAME=my-feature

# Copy config values manually (usually automatic in headless mode)
make vm-copy-config CLUSTER_PREFIX=my-test
```

#### Default Behavior

- `CUSTOMER_NAME` defaults to current git branch name
- `CLUSTER_PREFIX` defaults to "storagebox"
- The download target automatically resolves:
  - Customer ID from name
  - License ID from customer
  - Channel from customer's assignment

### Breaking Changes Checklist

When updating to major versions:
- Review upstream CHANGELOG for breaking changes
- Test component enable/disable toggles
- Verify TLS configurations (especially Cassandra)
- Test backup/restore functionality
- Verify preflights and support bundle collection
- Check for deprecated Kubernetes APIs

## Testing

### Local Validation

Validate Helm templates locally:
```bash
helm template storagebox ./charts/storagebox --debug
```

Lint the chart:
```bash
helm lint ./charts/storagebox
```

Validate KOTS manifests:
```bash
# Uses kots-lint.yaml for linting rules
replicated release lint --yaml-dir ./kots
```

### Deployment Testing Workflow

#### Quick Start - Full Test Cycle

The fastest way to test is using the `test-cycle` target which automates the entire workflow:

```bash
# This will:
# 1. Clean, package, and create a release
# 2. Create a test cluster
# 3. Get kubeconfig
# 4. Print next steps for deployment
make test-cycle CHANNEL=test-v018-k8s131
```

After the cluster is ready, follow the printed instructions:
```bash
# Deploy the application
make deploy CLUSTER_NAME=storagebox-0.18.0 CHANNEL=test-v018-k8s131

# Check status
make cluster-status CLUSTER_NAME=storagebox-0.18.0

# View logs
make deploy-logs CLUSTER_NAME=storagebox-0.18.0

# Clean up when done
make cluster-rm CLUSTER_NAME=storagebox-0.18.0
```

#### Manual Step-by-Step Testing

For more control over the testing process:

**1. Create and promote a release:**
```bash
make clean
make package-and-update
replicated release create --yaml-dir ./kots --promote test-v018-k8s131 --version "0.18.0"
```

**2. Create a test cluster:**
```bash
make cluster-create CLUSTER_NAME=my-test-cluster
```

**3. Wait for cluster to be ready (1-2 minutes), then get kubeconfig:**
```bash
make cluster-kubeconfig CLUSTER_NAME=my-test-cluster
```

**4. Deploy the application:**
```bash
make deploy CLUSTER_NAME=my-test-cluster CHANNEL=test-v018-k8s131
```

**5. Verify deployment:**
```bash
# Check overall status
make cluster-status CLUSTER_NAME=my-test-cluster

# Check KOTS app status
make deploy-status CLUSTER_NAME=my-test-cluster

# View logs
make deploy-logs CLUSTER_NAME=my-test-cluster
```

**6. Test storage backends:**

Set your KUBECONFIG and test each component:
```bash
export KUBECONFIG=~/.kube/my-test-cluster-config

# Test Cassandra
kubectl get pods -l app.kubernetes.io/name=cassandra
kubectl logs cassandra-0

# Test PostgreSQL
kubectl get clusters.postgresql.cnpg.io
kubectl get pods -l cnpg.io/cluster

# Test MinIO
kubectl get tenant -n default
kubectl get pods -l v1.min.io/tenant

# Test NFS
kubectl get pods -l app=nfs-server
```

**7. Clean up:**
```bash
make cluster-rm CLUSTER_NAME=my-test-cluster
```

### Testing Different Configurations

**Test with different Kubernetes versions:**
```bash
make cluster-create CLUSTER_NAME=test-k8s-130 K8S_VERSION=1.30
make cluster-create CLUSTER_NAME=test-k8s-131 K8S_VERSION=1.31
```

**Test with different distributions:**
```bash
make cluster-create CLUSTER_NAME=test-k3s DISTRIBUTION=k3s
make cluster-create CLUSTER_NAME=test-kind DISTRIBUTION=kind
make cluster-create CLUSTER_NAME=test-eks DISTRIBUTION=eks
```

**Test different channels:**
```bash
make deploy CLUSTER_NAME=my-test CHANNEL=test-v018-k8s131
make deploy CLUSTER_NAME=my-test CHANNEL=test-v017
make deploy CLUSTER_NAME=my-test CHANNEL=Unstable
```

### Cluster Management Tips

**List all active clusters:**
```bash
make cluster-list
```

**Monitor cluster resources:**
```bash
# Get kubeconfig if you don't have it
make cluster-kubeconfig CLUSTER_NAME=my-test

# Set KUBECONFIG and use kubectl directly
export KUBECONFIG=~/.kube/my-test-config
kubectl get nodes
kubectl get pods -A
kubectl top nodes
kubectl top pods -A
```

**Cluster TTL (Time-to-Live):**
- Default is 4 hours
- Clusters are automatically deleted after TTL expires
- Extend if needed: `make cluster-create TTL=8h`

## Common Issues and Troubleshooting

### Makefile sed errors

The `make package-and-update` target uses `sed -i ''` which is macOS-specific syntax. If running on Linux, the Makefile may need adjustment to use `sed -i` without the empty string argument.

### Dependency version mismatches

**Symptom**: MinIO Tenant resources fail to create or CRDs are missing
**Cause**: MinIO operator version in `kots/ec.yaml` doesn't match tenant chart version in `Chart.yaml`
**Fix**: Ensure both are updated to the same version (e.g., both 7.1.1)

**Symptom**: PostgreSQL Cluster CR not recognized
**Cause**: CloudnativePG operator not installed or wrong version
**Fix**: Verify operator version in `kots/ec.yaml` supports the API version in `templates/postgres-db.yaml`

### Helm dependency issues

**Symptom**: `helm dependency update` fails to pull charts
**Cause**: Missing Helm repositories
**Fix**: Run `make add-helm-repositories` first, or manually add repositories:
```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo add minio-operator https://operator.min.io
helm repo add jetstack https://charts.jetstack.io
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

### Chart version not updating

**Symptom**: `kots/storagebox-chart.yaml` shows old `chartVersion` after running `make package-and-update`
**Cause**: sed pattern matching issue or file not found
**Fix**: Manually update the `chartVersion` field in `kots/storagebox-chart.yaml` to match `Chart.yaml`

## Current Version Status

- **Chart Version**: 0.18.0
- **Embedded Cluster**: 2.10.0+k0s-1.31
- **Kubernetes Version**: 1.31 (k0s distribution)
- **Last Updated**: 2026-01-22

## Application CRD

The file `kots/k8s-app.yaml` uses `app.k8s.io/v1beta1` which is the current and only version of the Kubernetes Application CRD from the [kubernetes-sigs/application](https://github.com/kubernetes-sigs/application) project. This is **not deprecated** and is compatible with Kubernetes 1.31.

Note: This is different from the CRD definition API (`apiextensions.k8s.io/v1beta1`) which was deprecated. The Application resource itself (`app.k8s.io/v1beta1`) is actively maintained and has no stable v1 version yet.

The Application CRD is optional metadata for KOTS and may need to be installed separately if not already present in the cluster.
