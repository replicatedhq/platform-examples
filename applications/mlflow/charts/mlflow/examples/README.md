# MLflow Helm Chart Examples

This directory contains various example values files for deploying MLflow with different configurations, organized by category.

## Directory Structure

```
examples/
├── database/                # Database configuration examples
│   ├── embedded/           # Embedded PostgreSQL examples
│   └── external/           # External PostgreSQL examples
├── network/                 # Network configuration examples
│   ├── ingress/            # Ingress configuration examples
│   └── loadbalancer/       # LoadBalancer configuration examples
└── object-storage/          # Object storage configuration examples
    ├── embedded/           # Embedded MinIO examples
    └── external/           # External S3 storage examples
```

## Available Examples

### Database Configurations
- **Database Examples**: [database/README.md](./database/README.md)
  - **Embedded PostgreSQL**: [database/embedded/values.yaml](./database/embedded/values.yaml)
  - **External PostgreSQL (Direct Credentials)**: [database/external/direct-credentials.yaml](./database/external/direct-credentials.yaml)
  - **External PostgreSQL (Existing Secret)**: [database/external/existing-secret.yaml](./database/external/existing-secret.yaml)

### Network Configurations
- **Network Examples**: [network/README.md](./network/README.md)
  - **Ingress**: [network/ingress/values.yaml](./network/ingress/values.yaml)
  - **LoadBalancer**: [network/loadbalancer/values.yaml](./network/loadbalancer/values.yaml)

### Object Storage Configurations
- **Object Storage Examples**: [object-storage/README.md](./object-storage/README.md)
  - **Embedded MinIO**: [object-storage/embedded/values.yaml](./object-storage/embedded/values.yaml)
  - **External S3 (Direct Credentials)**: [object-storage/external/direct-credentials.yaml](./object-storage/external/direct-credentials.yaml)
  - **External S3 (Existing Secret)**: [object-storage/external/existing-secret.yaml](./object-storage/external/existing-secret.yaml)

## Usage

You can use these example values files as a starting point for your own deployment:

```bash
helm install mlflow ./charts/mlflow -f ./charts/mlflow/examples/database/embedded/values.yaml
```

Or combine multiple example files:

```bash
helm install mlflow ./charts/mlflow \
  -f ./charts/mlflow/examples/database/embedded/values.yaml \
  -f ./charts/mlflow/examples/network/ingress/values.yaml
```

## Customization

These examples provide basic configurations. For production deployments, make sure to:

1. Set secure passwords
2. Configure proper TLS certificates
3. Adjust resource requests and limits
4. Review other settings in the main `values.yaml` file

Refer to the main [README.md](../README.md) for complete configuration options. 