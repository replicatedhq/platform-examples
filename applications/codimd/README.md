# CodiMD: Collaborative Markdown Editor

CodiMD is a real-time collaborative markdown editor that enables multiple users to simultaneously edit and view documents. This repository contains the Helm chart and Replicated manifests needed to deploy CodiMD to a Kubernetes cluster.

## Overview

- **Application Version**: 2.5.4
- **License**: AGPL-3.0
- **Chart Version**: 0.1.0

## Features

- Real-time collaborative editing
- Markdown syntax highlighting
- Document versioning
- Access control and permissions
- Code highlighting
- Math expressions (KaTeX)
- Diagrams (mermaid)

## Requirements

- Kubernetes v1.16.0+
- Helm v3.0+
- 4GB minimum cluster memory
- 2 CPU cores minimum
- Default storage class configured
- Docker or containerd runtime (cri-o not supported)

## Components

CodiMD uses the following dependencies:

- **PostgreSQL** (v12.0.1): Database for storing notes and user data
- **Redis** (v17.0.11): Session management and real-time functionality

## Installation

### Using Replicated KOTS

```bash
# Install the Replicated CLI
curl -s https://kots.io/install | bash

# Install CodiMD
kubectl kots install codimd

# Follow the on-screen instructions to complete the installation
```

### Using Helm directly

```bash
# Add the chart repository
helm repo add codimd https://charts.example.com/codimd

# Install the chart
helm install codimd ./charts/codimd -f ./charts/codimd/values.yaml
```

## Configuration

Key configuration parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `database.type` | Database type (internal/external) | `internal` |
| `database.postgresql.enabled` | Deploy PostgreSQL | `true` |
| `redis.enabled` | Deploy Redis | `true` |
| `codimd.allowAnonymous` | Allow anonymous access | `true` |
| `codimd.defaultPermission` | Default note permissions | `editable` |
| `codimd.imageUpload` | Enable image uploads | `true` |

For complete configuration options, see the values.yaml file in the chart.

## Development

```bash
# Validate the Helm chart
task validate

# Package the Helm chart
task package

# Create a new release in Replicated
task create-release

# Deploy chart for testing
task deploy-helm
```

## Troubleshooting

Common issues:

1. **Database connection failures**: Check PostgreSQL pod status and logs
2. **Redis connection issues**: Verify Redis service is running
3. **Permission errors**: Ensure proper storage class permissions

## License

This project is licensed under the AGPL-3.0 License.