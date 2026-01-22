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
```

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

### VM Testing

**Note**: VM testing targets are NOT available in this directory. VM infrastructure and testing workflows exist at a different level in the organization. To test Embedded Cluster installations:

1. Create a test release: `replicated release create --yaml-dir ./kots --promote test-channel`
2. Deploy using Replicated's compatibility matrix (CMX) or manual VM provisioning
3. Use the install command from the vendor portal

### Breaking Changes Checklist

When updating to major versions:
- Review upstream CHANGELOG for breaking changes
- Test component enable/disable toggles
- Verify TLS configurations (especially Cassandra)
- Test backup/restore functionality
- Verify preflights and support bundle collection
- Check for deprecated Kubernetes APIs

## Testing

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
