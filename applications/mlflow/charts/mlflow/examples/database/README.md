# Database Configuration Examples

This directory contains examples for configuring the MLflow database backends.

## Embedded

The `embedded` directory contains examples for using the built-in PostgreSQL database provided by the CloudNativePG operator.

- [values.yaml](./embedded/values.yaml): Configuration for embedded PostgreSQL

## External

The `external` directory contains examples for connecting to an external PostgreSQL database:

- [direct-credentials.yaml](./external/direct-credentials.yaml): Configure access using credentials specified in the values file
- [existing-secret.yaml](./external/existing-secret.yaml): Configure access using credentials stored in a Kubernetes secret 