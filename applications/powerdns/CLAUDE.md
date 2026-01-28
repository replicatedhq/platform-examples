# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PowerDNS DNS server stack packaged as a Replicated KOTS application for Embedded Cluster deployment. Includes:
- **PowerDNS Authoritative Server** - Primary DNS server with PostgreSQL backend
- **PowerDNS Recursor** - Caching DNS resolver that forwards local domain queries to the authoritative server
- **PowerDNS-Admin** - Web interface for DNS management
- **CloudNativePG** - PostgreSQL operator for database persistence

## Build and Release Commands

```bash
# Full release workflow (clean, package charts, create Replicated release)
make release

# Package Helm charts and update versions in manifests
make package-and-update

# Update Helm chart dependencies
make update-chart-dependencies

# Pull external chart dependencies (CloudNativePG)
make pull-chart-dependencies

# Check current chart versions
make check-versions

# Clean packaged chart archives
make clean
```

## Architecture

### Helm Charts (bjw-s Common Library Pattern)

All custom charts use the [bjw-s common library chart](https://bjw-s.github.io/helm-charts) pattern. Templates delegate to the common library via `templates/common.yaml`:

```yaml
{{- include "bjw-s.common.loader.init" . }}
{{ include "bjw-s.common.loader.generate" . }}
```

Values files define workloads using the library schema (controllers, services, persistence, configMaps). The `values.yaml` schema reference is at the top of each file.

### Chart Dependencies

- **powerdns-authoritative**: Depends on `bjw-s/common` and `replicated` SDK charts
- **powerdns-recursor**: Depends on `bjw-s/common`
- **cloudnative-pg**: Wrapper chart pulling upstream `cnpg/cloudnative-pg`

### KOTS Manifests (`manifests/`)

- `kots-app.yaml` - Application metadata and status informers
- `kots-config.yaml` - Customer-facing configuration (ingress, database settings)
- `ec.yaml` - Embedded Cluster configuration with ingress-nginx extension
- `*-chart.yaml` - HelmChart resources linking packaged `.tgz` archives

### PostgreSQL Integration

The authoritative server uses CloudNativePG for PostgreSQL:
- Cluster defined in `templates/postgres-cluster.yaml`
- Init SQL schema in `values.yaml` under `configMaps.initdb`
- Credentials managed via `templates/pdns-db-credentials.yaml`

## Key Patterns

### Chart Versioning

Chart versions in `Chart.yaml` must match `chartVersion` in `manifests/*-chart.yaml`. The `make package-and-update` target synchronizes these automatically.

### Embedded Cluster Configuration

The `ec.yaml` extends the Kubernetes service node port range to `21-32767` via k0s unsupported overrides, allowing DNS on standard ports.

### Template Development

When modifying Helm templates, validate rendering with:
```bash
helm template charts/powerdns-authoritative
helm template charts/powerdns-recursor
```

Lint charts before packaging:
```bash
helm lint charts/powerdns-authoritative
helm lint charts/powerdns-recursor
```
