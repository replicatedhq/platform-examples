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

## Documentation

- [MLflow Helm Chart Documentation](./charts/mlflow/README.md) - Installation and configuration details
- [Configuration Reference](./charts/mlflow/README_CONFIG.md) - Detailed configuration options
- [Development Guide](./DEVELOPMENT.md) - Guide for development including containerized environment

## For Developers

If you're looking to contribute to or customize this application, please refer to our comprehensive [Development Guide](./DEVELOPMENT.md). The development guide covers:

- Development workflow with Taskfile
- Local testing instructions
- Release process
- CI/CD integration
- Helm chart customization
- Containerized development environment

For containerized development, we offer a Docker-based development environment:

```bash
# Enter the development container shell
task dev:shell

# For Kubernetes development with Kind
task dev:shell:kind
```

See the [Development Guide](./DEVELOPMENT.md) for more details.

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
  - Embedded PostgreSQL (default): Automatically deployed with the chart
  - External PostgreSQL (optional): Connect to your existing database
- **MinIO**: S3-compatible storage for artifacts and model files 
  - Embedded MinIO (default): Automatically deployed with the chart
  - External S3-compatible storage (optional): Connect to your existing object storage
- **Replicated Integration**: Management layer for installation and updates

### Storage Options

This solution offers flexibility in how you store MLflow data:

#### Metadata Storage

- **Embedded PostgreSQL** (Default): Simplifies deployment with an automatically managed database
- **External PostgreSQL**: Connect to your existing PostgreSQL instance for better control, scaling, and integration with your infrastructure

#### Artifact Storage

- **Embedded MinIO** (Default): Provides S3-compatible storage within the deployment
- **External S3-compatible Storage**: Store artifacts in your own S3, GCS, or other S3-compatible storage service

See the [Configuration Reference](./charts/mlflow/README_CONFIG.md) for detailed setup instructions.

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

# Update dependencies and install charts
task helm:update-deps

# Install charts locally with Replicated SDK disabled
task helm:install-local

# Access MLflow UI at http://localhost:5000
```

For more details on using the Taskfile for development and releasing, see the [Development Guide](./DEVELOPMENT.md).

## Support

For support with this application, please visit the [Replicated Community](https://community.replicated.com/).
