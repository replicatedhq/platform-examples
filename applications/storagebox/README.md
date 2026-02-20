# Storagebox

This application is a collection of storage options for use with apps deployed on Kubernetes.  It includes:

- Apache Cassandra [deployed with K8ssandra operator](https://k8ssandra.io/)
- NFS Server [deployed with Obéone helm chart](https://github.com/obeonetwork/charts/tree/master/stable/nfs-server)
- MinIO [deployed with MinIO Operator](https://github.com/minio/operator/tree/master/helm/minio)
- Postgres [deployed with Cloudnative-PG Operator](https://github.com/cloudnative-pg/cloudnative-pg)

Currently, it is designed to be used as an EC application.  Cluster-scope dependencies (the Operators for K8ssandra, Minio, and Postgres) are deployed as part of the EC lifecycle and are not managed by the Storagebox chart.

Each component can be enabled or disabled from the EC admin console or via helm values `enabled` field.  The default is to enable all components.

## Future Work

The Storagebox application is currently in development and is not yet ready for production use.  The following features are planned for future releases:

- Support for other storage options
  - Ceph
  - local block storage
  - MySQL
  - Redis
