# Object Storage Configuration Examples

This directory contains examples for configuring the artifact object storage for MLflow.

## Embedded

The `embedded` directory contains examples for using the built-in MinIO object storage:

- [values.yaml](./embedded/values.yaml): Configuration for embedded MinIO as artifact storage

## External

The `external` directory contains examples for connecting to external S3-compatible storage:

- [direct-credentials.yaml](./external/direct-credentials.yaml): Configure access using credentials specified in the values file
- [existing-secret.yaml](./external/existing-secret.yaml): Configure access using credentials stored in a Kubernetes secret 