# MLflow on Replicated

MLflow is an open-source platform for managing the machine learning lifecycle, including experimentation, reproducibility, deployment, and a central model registry. This solution provides MLflow deployment with Replicated, supporting multiple installation methods to fit your environment needs.

## Overview

This Replicated application offers MLflow with:

- Comprehensive tracking and model registry capabilities
- PostgreSQL backend for metadata storage
- MinIO for artifact storage
- Multiple deployment options for flexibility

## Deployment Options

### Helm Chart

For customers who prefer direct Helm installation:
- Standard Helm chart interface
- Integration with existing CI/CD pipelines
- Full configurability via values

```bash
# Add Replicated registry with your license ID
helm registry login registry.replicated.com --username=<license-id>

# Install via Helm
helm install mlflow oci://registry.replicated.com/mlflow/stable
```

### Embedded Cluster

For customers without an existing Kubernetes cluster, the embedded option provides:
- Integrated Kubernetes cluster managed by Replicated
- Simple installation on VMs or bare metal
- No Kubernetes expertise required
- Optimized resource usage

```bash
# Download installer from the provided license URL
# Run the installer script
bash ./install.sh
```

### KOTS Existing Cluster

For customers with existing Kubernetes clusters, the KOTS installation method provides:
- Admin console for application management
- Version updates with rollback capability
- Configuration validation
- Pre-flight checks to verify environment requirements

```bash
# Install KOTS CLI
curl https://kots.io/install | bash

# Install MLflow with KOTS
kubectl kots install mlflow/stable
```

## Documentation

- [MLflow Helm Chart Documentation](./charts/mlflow/README.md) - Installation and configuration details
- [Configuration Reference](./charts/mlflow/README_CONFIG.md) - Detailed configuration options

## For Developers

If you're looking to contribute to or customize this application, please refer to our comprehensive [Development Guide](./DEVELOPMENT.md). The development guide covers:

- Development workflow with Taskfile
- Local testing instructions
- Release process
- CI/CD integration
- Helm chart customization

We use [helm-docs](https://github.com/norwoodj/helm-docs) for chart documentation. See the [Development Guide](./DEVELOPMENT.md) for details.

## MLflow Features

This Replicated distribution includes the following MLflow features:

- **Experiment Tracking**: Record parameters, metrics, code versions, and artifacts
- **Model Registry**: Store, annotate, and manage model versions in a central repository
- **Model Serving**: Deploy models for inference with version control
- **Project Management**: Package data science code for reproducibility

## Architecture

The solution architecture consists of:

- **MLflow Server**: Core MLflow tracking and registry services
- **PostgreSQL**: Metadata storage for experiments, runs, and models
- **MinIO**: S3-compatible storage for artifacts and model files 
- **Replicated Integration**: Management layer for installation and updates

## Getting Started

### Prerequisites

- For KOTS: Kubernetes cluster v1.19+ or admin access to install embedded cluster
- For Helm: Helm v3.0+ and a Kubernetes cluster
- Valid Replicated license

### Quick Start for Development

For local development with the Helm charts:

```bash
# Clone this repository
git clone https://github.com/replicatedhq/platform-examples.git
cd platform-examples/applications/mlflow

# Install Task CLI (if not already installed)
# See https://taskfile.dev/#/installation

# Add required Helm repositories and update dependencies
task add:repos:helm
task update:deps:helm

# Install charts locally with Replicated SDK disabled
task install:helm:local

# Access MLflow UI at http://localhost:5000
```

For more details on using the Taskfile for development and releasing, see the [Development Guide](./DEVELOPMENT.md).

## Support

For support with this application, please visit the [Replicated Community](https://community.replicated.com/).
