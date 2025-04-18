# mlflow

A Helm chart for MLflow - Open source platform for the machine learning lifecycle.

![Version: 0.4.0](https://img.shields.io/badge/Version-0.4.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 2.10.0](https://img.shields.io/badge/AppVersion-2.10.0-informational?style=flat-square)

## Introduction

MLflow is an open-source platform for managing the machine learning lifecycle, including:
- Experiment tracking: Record and compare parameters, data, code, and results
- Model registry: Store, annotate, discover, and manage models in a central repository
- Model serving: Deploy models in diverse serving environments

This Helm chart deploys MLflow with a PostgreSQL database for tracking and MinIO for artifact storage.

## Source Code

* <https://github.com/mlflow/mlflow/tree/master/charts/mlflow>

## Requirements

## Dependencies

| Repository | Name | Version |
|------------|------|---------|
| oci://registry.replicated.com/library | replicated | ^1.1.0 |

## Installing the Chart

### Prerequisites
- Kubernetes cluster running version 1.19+
- Helm 3.0+
- Persistent storage provisioner (for PostgreSQL and MinIO)

### Quick Start

```bash
# Add the Replicated registry (if using Replicated)
helm registry login registry.replicated.com --username=<your-license-id>

# Install the chart
helm install mlflow oci://registry.replicated.com/your-app/your-channel/mlflow
```

### From Local Chart

```bash
# Clone the repository
git clone https://github.com/replicatedhq/platform-examples.git
cd platform-examples/applications/mlflow

# Install dependencies
helm dependency update ./charts/mlflow

# Install the chart
helm install mlflow ./charts/mlflow --namespace mlflow --create-namespace
```

## Usage

### Accessing MLflow

After deploying MLflow, you can access the web UI by port-forwarding the service:

```bash
kubectl port-forward -n mlflow svc/mlflow 5000:5000
```

Then navigate to http://localhost:5000 in your browser.

## Features

- **Tracking Server**: Central interface for logging parameters, metrics, and artifacts
- **Model Registry**: Repository for managing the full lifecycle of MLflow Models
- **PostgreSQL**: Persistent storage for experiment and run data
- **MinIO**: S3-compatible storage for model artifacts
- **Replicated Integration**: Support for distribution through the Replicated platform

## Configuration

The following table lists the configurable parameters for the MLflow chart and their default values.

For detailed configuration options, see the [Configuration Reference](./README_CONFIG.md).

### Basic Configuration

#### Minimum Configuration

```yaml
# Minimal configuration example
postgresql:
  auth:
    password: "securePassword"  # Required for security
minio:
  auth:
    rootPassword: "securePassword"  # Required for security
```

#### Common Configuration Options

```yaml
# Common options
mlflow:
  # Set resources for MLflow server
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"
 
  # Configure basic authentication
  auth:
    enabled: true
    username: admin
    password: password
```

For complete configuration options including external services, security settings, and advanced features, see the [Configuration Reference](./README_CONFIG.md).

## Uninstalling the Chart

```bash
helm uninstall mlflow -n mlflow
```

## Changelog

The changelog for this chart is maintained in [README_CHANGELOG.md](./README_CHANGELOG.md).

## Support

For support with this chart, please visit the [Replicated Community](https://community.replicated.com/).

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)# Configuration

This document outlines the configuration options for the MLflow Helm chart.

The following table lists the configurable parameters for the MLflow chart and their default values.

## Advanced Configuration

### PostgreSQL Configuration

The chart uses PostgreSQL for storing MLflow metadata. You can configure the database connection using:

```yaml
postgresql:
  enabled: true
  auth:
    username: mlflow
    password: mlflowpassword
    database: mlflow
  primary:
    persistence:
      size: 10Gi
```

### MinIO Configuration

MinIO is used for artifact storage. Configure it with:

```yaml
minio:
  enabled: true
  auth:
    rootUser: minioadmin
    rootPassword: minioadmin
  persistence:
    size: 20Gi
  defaultBuckets: "mlflow"
```

### Using External Storage

To use external PostgreSQL:

```yaml
postgresql:
  enabled: false

mlflow:
  backendStore:
    databaseUri: "postgresql://user:password@external-postgresql:5432/mlflow"
```

To use external S3-compatible storage:

```yaml
minio:
  enabled: false

mlflow:
  artifactRoot:
    s3:
      enabled: true
      bucket: "mlflow"
      endpoint: "s3.amazonaws.com"
      accessKey: "your-access-key"
      secretKey: "your-secret-key"
      region: "us-east-1"
```

### Replicated SDK Integration

Enable or disable the Replicated SDK integration:

```yaml
replicated:
  enabled: true
```

For development environments, you'll typically want to disable this:

```yaml
replicated:
  enabled: false
```

### Security Considerations

By default, this chart doesn't include authentication. In production, consider:

1. Using an ingress with authentication
2. Setting up TLS encryption
3. Configuring username/password protection

Example ingress configuration with TLS:

```yaml
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: mlflow.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: mlflow-tls
      hosts:
        - mlflow.example.com
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| fullnameOverride | string | `"mlflow"` | String to override the default generated fullname |
| minio.enabled | bool | `true` |  |
| minio.secrets.accessKey | string | `"minio"` |  |
| minio.secrets.name | string | `"myminio-env-configuration"` |  |
| minio.secrets.secretKey | string | `"minio1234"` |  |
| minio.tenant.additionalVolumeMounts | list | `[]` | An array of volume mount points associated to each Tenant container. |
| minio.tenant.additionalVolumes | list | `[]` | An array of `Volumes <https://kubernetes.io/docs/concepts/storage/volumes/>`__ which the Operator can mount to Tenant pods. The volumes must exist *and* be accessible to the Tenant pods. |
| minio.tenant.buckets | list | `[{"name":"mlflow"}]` | Array of objects describing one or more buckets to create during tenant provisioning. |
| minio.tenant.certificate | object | `{"certConfig":{},"externalCaCertSecret":[],"externalCertSecret":[],"requestAutoCert":true}` | Configures external certificate settings for the Tenant. |
| minio.tenant.certificate.certConfig | object | `{}` | See `Operator CRD: CertificateConfig <https://min.io/docs/minio/kubernetes/upstream/reference/operator-crd.html#certificateconfig>`__ |
| minio.tenant.certificate.externalCaCertSecret | list | `[]` | Specify an array of Kubernetes TLS secrets, where each entry corresponds to a secret the TLS private key and public certificate pair. See `Operator CRD: TenantSpec <https://min.io/docs/minio/kubernetes/upstream/reference/operator-crd.html#tenantspec>`__. |
| minio.tenant.certificate.externalCertSecret | list | `[]` | Specify an array of Kubernetes secrets, where each entry corresponds to a secret contains the TLS private key and public certificate pair. See `Operator CRD: TenantSpec <https://min.io/docs/minio/kubernetes/upstream/reference/operator-crd.html#tenantspec>`__. |
| minio.tenant.configuration | object | `{"name":"myminio-env-configuration"}` | The Kubernetes secret name that contains MinIO environment variable configurations. The secret is expected to have a key named config.env containing environment variables exports. |
| minio.tenant.env | list | `[]` | Add environment variables to be set in MinIO container (https://github.com/minio/minio/tree/master/docs/config) |
| minio.tenant.exposeServices | object | `{}` | Directs the Operator to deploy the MinIO S3 API and Console services as LoadBalancer objects. If the Kubernetes cluster has a configured LoadBalancer, it can attempt to route traffic to those services automatically. Specify ``minio: true`` to expose the MinIO S3 API. Specify ``console: true`` to expose the Console. Both fields default to ``false``. |
| minio.tenant.features | object | `{"bucketDNS":false,"domains":{},"enableSFTP":false}` | MinIO features to enable or disable in the MinIO Tenant See `Operator CRD: Features <https://min.io/docs/minio/kubernetes/upstream/reference/operator-crd.html#features>`__. |
| minio.tenant.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| minio.tenant.image.repository | string | `"quay.io/minio/minio"` | Image repository |
| minio.tenant.image.tag | string | `"RELEASE.2024-05-01T01-11-10Z"` | Image tag |
| minio.tenant.imagePullSecret | object | `{}` | Image pull secrets |
| minio.tenant.lifecycle | object | `{}` | The `Lifecycle hooks <https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/>`__ for container. |
| minio.tenant.liveness | object | `{}` | The `Liveness Probe <https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes>`__ for monitoring Tenant pod liveness. Tenant pods will be restarted if the probe fails. |
| minio.tenant.logging | object | `{}` | Configure pod logging configuration for the MinIO Tenant. Specify ``json`` for JSON-formatted logs. Specify ``anonymous`` for anonymized logs. Specify ``quiet`` to supress logging. |
| minio.tenant.metrics | object | `{"enabled":false,"port":9000,"protocol":"http"}` | Configures a Prometheus-compatible scraping endpoint at the specified port. |
| minio.tenant.mountPath | string | `"/export"` | The mount path where Persistent Volumes are mounted inside Tenant container(s). |
| minio.tenant.name | string | `"minio"` | Minio Tenant name |
| minio.tenant.podManagementPolicy | string | `"Parallel"` | The `PodManagement <https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/#pod-management-policy>`__ policy for MinIO Tenant Pods. Can be "OrderedReady" or "Parallel" |
| minio.tenant.pools | object | `{"pool0":{"affinity":{},"annotations":{},"containerSecurityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000,"seccompProfile":{"type":"RuntimeDefault"}},"labels":{},"name":"pool-0","nodeSelector":{},"podAntiAffinityMode":"soft","podAntiAffinityTopologyKey":"","resources":{},"runtimeClassName":"","securityContext":{"fsGroup":1000,"fsGroupChangePolicy":"OnRootMismatch","runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000},"servers":3,"size":"10Gi","storageAnnotations":{},"tolerations":[],"topologySpreadConstraints":[],"volumesPerServer":4}}` | See `Operator CRD: Pools <https://min.io/docs/minio/kubernetes/upstream/reference/operator-crd.html#pool>`__ for more information on all subfields. |
| minio.tenant.pools.pool0 | object | `{"affinity":{},"annotations":{},"containerSecurityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000,"seccompProfile":{"type":"RuntimeDefault"}},"labels":{},"name":"pool-0","nodeSelector":{},"podAntiAffinityMode":"soft","podAntiAffinityTopologyKey":"","resources":{},"runtimeClassName":"","securityContext":{"fsGroup":1000,"fsGroupChangePolicy":"OnRootMismatch","runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000},"servers":3,"size":"10Gi","storageAnnotations":{},"tolerations":[],"topologySpreadConstraints":[],"volumesPerServer":4}` | The number of MinIO Tenant Pods / Servers in this pool. For standalone mode, supply 1. For distributed mode, supply 4 or more. Note that the operator does not support upgrading from standalone to distributed mode. |
| minio.tenant.pools.pool0.affinity | object | `{}` | Affinity/Anti-affinity rules for Pods. See: https://cloudnative-pg.io/documentation/current/cloudnative-pg.v1/#postgresql-cnpg-io-v1-AffinityConfiguration |
| minio.tenant.pools.pool0.annotations | object | `{}` | Specify `annotations <https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/>`__ to associate to Tenant pods. |
| minio.tenant.pools.pool0.containerSecurityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000,"seccompProfile":{"type":"RuntimeDefault"}}` | The Kubernetes `SecurityContext <https://kubernetes.io/docs/tasks/configure-pod-container/security-context/>`__ to use for deploying Tenant containers. |
| minio.tenant.pools.pool0.labels | object | `{}` | Specify `labels <https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/>`__ to associate to Tenant pods. |
| minio.tenant.pools.pool0.name | string | `"pool-0"` | Custom name for the pool |
| minio.tenant.pools.pool0.nodeSelector | object | `{}` | Any `Node Selectors <https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/>`__ to apply to Tenant pods. |
| minio.tenant.pools.pool0.podAntiAffinityMode | string | `"soft"` | Specifies whether podAntiAffinity should be "required" or simply "preferred" This determines if requiredDuringSchedulingIgnoredDuringExecution or preferredDuringSchedulingIgnoredDuringExecution is used [[ref]](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity) |
| minio.tenant.pools.pool0.podAntiAffinityTopologyKey | string | `""` | Enables podAntiAffinity with the specified topology key .minio.tenant.pool.pool0.affinity takes precedence over this setting |
| minio.tenant.pools.pool0.resources | object | `{}` | The `Requests or Limits <https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/>`__ for resources to associate to Tenant pods. |
| minio.tenant.pools.pool0.runtimeClassName | string | `""` | The name of a custom `Container Runtime <https://kubernetes.io/docs/concepts/containers/runtime-class/>`__ to use for the Operator Console pods. |
| minio.tenant.pools.pool0.securityContext | object | `{"fsGroup":1000,"fsGroupChangePolicy":"OnRootMismatch","runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000}` | The Kubernetes `SecurityContext <https://kubernetes.io/docs/tasks/configure-pod-container/security-context/>`__ to use for deploying Tenant resources. |
| minio.tenant.pools.pool0.size | string | `"10Gi"` | The capacity per volume requested per MinIO Tenant Pod. |
| minio.tenant.pools.pool0.storageAnnotations | object | `{}` | Specify `storageAnnotations <https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/>`__ to associate to PVCs. |
| minio.tenant.pools.pool0.tolerations | list | `[]` | An array of `Toleration labels <https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/>`__ to associate to Tenant pods. |
| minio.tenant.pools.pool0.topologySpreadConstraints | list | `[]` | An array of `Topology Spread Constraints <https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/>`__ to associate to Operator Console pods. |
| minio.tenant.pools.pool0.volumesPerServer | int | `4` | The number of volumes attached per MinIO Tenant Pod / Server. |
| minio.tenant.priorityClassName | string | `""` | PriorityClassName indicates the Pod priority and hence importance of a Pod relative to other Pods. This is applied to MinIO pods only. Refer Kubernetes documentation for details https://kubernetes.io/docs/concepts/configuration/pod-priority-preemption/#priorityclass/ |
| minio.tenant.prometheusOperator | bool | `false` | Directs the Operator to add the Tenant's metric scrape configuration to an existing Kubernetes Prometheus deployment managed by the Prometheus Operator. |
| minio.tenant.scheduler | object | `{}` |  |
| minio.tenant.serviceAccountName | string | `""` | The `Kubernetes Service Account <https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/>`__ associated with the Tenant. |
| minio.tenant.serviceMetadata | object | `{}` | serviceMetadata allows passing additional labels and annotations to MinIO and Console specific services created by the operator. |
| minio.tenant.startup | object | `{}` | `Startup Probe <https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/>`__ for monitoring container startup. Tenant pods will be restarted if the probe fails. |
| minio.tenant.subPath | string | `"/data"` | The Sub path inside Mount path where MinIO stores data. |
| minio.tenant.users | list | `[]` | Array of Kubernetes secrets from which the Operator generates MinIO users during tenant provisioning. Each secret should specify the ``CONSOLE_ACCESS_KEY`` and ``CONSOLE_SECRET_KEY`` as the access key and secret key for that user. |
| mlflow.affinity | object | `{}` | Defines affinity constraint rules. [[ref]](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity) |
| mlflow.annotations | object | `{}` | Annotations to add to the mlflow deployment |
| mlflow.artifactStore.s3.accessKeyId | string | `"minio"` | AWS access key ID Used if S3 is enabled as an artifact storage backend and no existing secret is specified |
| mlflow.artifactStore.s3.createCaSecret | object | `{"caBundle":""}` | If S3 is enabled as artifact store backend and no existing CA secret is specified, create the secret used to secure connection to S3 / Minio |
| mlflow.artifactStore.s3.createCaSecret.caBundle | string | `""` | Content of CA bundle |
| mlflow.artifactStore.s3.enabled | bool | `true` | Specifies whether to enable AWS S3 as artifact store backend NOTE: Need to also ensure .mlflow.trackingServer.artifactsDestination is set to the correct S3 bucket |
| mlflow.artifactStore.s3.existingCaSecret | string | `""` | Name of an existing secret containing the key `ca-bundle.crt` used to store the CA certificate for TLS connections |
| mlflow.artifactStore.s3.existingSecret | string | `""` | Name of an existing secret containing the keys `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` to access artifact storage on AWS S3 or MINIO |
| mlflow.artifactStore.s3.external | object | `{"enabled":false,"host":"","ignoreTls":false,"port":443,"protocol":"https"}` | External S3 compatible bucket details Used if S3 is enabled as artifact storage backend, external.enabled is true, and no existing secret is specified |
| mlflow.artifactStore.s3.external.enabled | bool | `false` | Specifies whether to use an external S3 bucket |
| mlflow.artifactStore.s3.external.host | string | `""` | S3 endpoint host |
| mlflow.artifactStore.s3.external.ignoreTls | bool | `false` | Specify whether to ignore TLS |
| mlflow.artifactStore.s3.external.port | int | `443` | S3 endpoint port |
| mlflow.artifactStore.s3.external.protocol | string | `"https"` | S3 endpoint protocol https or http |
| mlflow.artifactStore.s3.ignoreTls | bool | `true` | Specify whether to ignore TLS |
| mlflow.artifactStore.s3.secretAccessKey | string | `"minio1234"` | AWS secret access key Used if S3 is enabled as an artifact storage backend and no existing secret is specified |
| mlflow.automountServiceAccountToken | bool | `true` | Specifies whether to automount service account token |
| mlflow.backendStore.databaseUpgrade | bool | `false` | Specifies whether to run `mlflow db upgrade ${MLFLOW_BACKEND_STORE_URI}` to upgrade database schema when use a database as backend store |
| mlflow.backendStore.existingSecret | string | `""` | Name of an existing secret which contains key `MLFLOW_BACKEND_STORE_URI` If an existing secret is not provided, a new secret will be created to store the backend store URI using the details from .Values.postgres when Embedded PostgreSQL is enabled |
| mlflow.containerSecurityContext | object | `{}` | Configure the Security Context for the Container |
| mlflow.dnsConfig | object | `{}` | Optional DNS settings, configuring the ndots option may resolve nslookup issues on some Kubernetes setups. |
| mlflow.dnsPolicy | string | `""` | Defaults to "ClusterFirst" if hostNetwork is false and "ClusterFirstWithHostNet" if hostNetwork is true |
| mlflow.enableServiceLinks | bool | `true` | Enable/disable the generation of environment variables for services. [[ref]](https://kubernetes.io/docs/concepts/services-networking/connect-applications-service/#accessing-the-service) |
| mlflow.env | object | `{"configMap":{},"container":[],"secret":{}}` | Extra environment variables in mlflow container |
| mlflow.extraContainers | list | `[]` | Extra containers belonging to the mlflow pod. |
| mlflow.extraEnvFrom | list | `[]` | Extra environment variable sources in mlflow container |
| mlflow.extraInitContainers | list | `[]` | Extra initialization containers belonging to the mlflow pod. |
| mlflow.extraVolumeMounts | list | `[]` | Extra volume mounts to mount into the mlflow container's file system |
| mlflow.extraVolumes | list | `[]` | Extra volumes that can be mounted by containers belonging to the mlflow pod |
| mlflow.hostAliases | list | `[]` | Use hostAliases to add custom entries to /etc/hosts - mapping IP addresses to hostnames. [[ref]](https://kubernetes.io/docs/concepts/services-networking/add-entries-to-pod-etc-hosts-with-host-aliases/) |
| mlflow.hostNetwork | bool | `false` | When using hostNetwork make sure you set dnsPolicy to `ClusterFirstWithHostNet` |
| mlflow.hostname | string | `""` | Allows specifying explicit hostname setting |
| mlflow.image | object | `{"pullPolicy":"IfNotPresent","registry":"docker.io","repository":"bitnami/mlflow","tag":"2.12.2-debian-12-r1"}` | Image configuration for the mlflow deployment |
| mlflow.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| mlflow.image.registry | string | `"docker.io"` | Image registry |
| mlflow.image.repository | string | `"bitnami/mlflow"` | Image repository |
| mlflow.image.tag | string | `"2.12.2-debian-12-r1"` | Image tag |
| mlflow.imagePullSecets | list | `[]` | Image pull secrets |
| mlflow.ingress | object | `{"annotations":{},"className":"nginx","enabled":false,"extraHosts":[],"extraPaths":[],"extraRules":[],"extraTls":[],"hostname":"chart-example.local","path":"/","pathType":"ImplementationSpecific","tls":{"cert":"-----BEGIN CERTIFICATE-----\n-----END CERTIFICATE-----\n","enabled":false,"genSelfSignedCert":false,"key":"-----BEGIN PRIVATE KEY-----\n-----END PRIVATE KEY-----\n"}}` | Mlflow Ingress configuration [[ref]](https://kubernetes.io/docs/concepts/services-networking/ingress/) |
| mlflow.ingress.annotations | object | `{}` | Annotations to add to the ingress |
| mlflow.ingress.className | string | `"nginx"` | Ingress class name |
| mlflow.ingress.enabled | bool | `false` | Specifies whether a ingress should be created |
| mlflow.ingress.extraHosts | list | `[]` | Extra hosts to configure for the ingress object |
| mlflow.ingress.extraPaths | list | `[]` | Extra paths to configure for the ingress object |
| mlflow.ingress.extraRules | list | `[]` | Extra rules to configure for the ingress object |
| mlflow.ingress.extraTls | list | `[]` | Extra tls hosts to configure for the ingress object |
| mlflow.ingress.hostname | string | `"chart-example.local"` | Ingress hostname |
| mlflow.ingress.path | string | `"/"` | Ingress path |
| mlflow.ingress.pathType | string | `"ImplementationSpecific"` | Ingress path type |
| mlflow.ingress.tls | object | `{"cert":"-----BEGIN CERTIFICATE-----\n-----END CERTIFICATE-----\n","enabled":false,"genSelfSignedCert":false,"key":"-----BEGIN PRIVATE KEY-----\n-----END PRIVATE KEY-----\n"}` | Ingress TLS configuration |
| mlflow.ingress.tls.enabled | bool | `false` | Specifies whether to enable TLS |
| mlflow.ingress.tls.genSelfSignedCert | bool | `false` | Specifies whether to generate self-signed certificate |
| mlflow.labels | object | `{}` | Labels to add to the mlflow deployment |
| mlflow.lifecycle | object | `{}` | Configure the lifecycle for the container |
| mlflow.nodeSelector | object | `{}` | Node selection constraint [[ref]](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |
| mlflow.podAntiAffinityMode | string | `"soft"` | Specifies whether podAntiAffinity should be "required" or simply "preferred" This determines if requiredDuringSchedulingIgnoredDuringExecution or preferredDuringSchedulingIgnoredDuringExecution is used [[ref]](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity) |
| mlflow.podAntiAffinityTopologyKey | string | `""` | Enables podAntiAffinity with the specified topology key .mlflow.affinity takes precedence over this setting |
| mlflow.podLabels | object | `{}` | Pod Labels for the mlflow deployment |
| mlflow.podSecurityContext | object | `{}` | Configure the Security Context for the Pod |
| mlflow.priorityClassName | string | `""` | Custom priority class for different treatment by the scheduler |
| mlflow.probes | object | `{"livenessProbe":{},"readinessProbe":{},"startupProbe":{}}` | Specify probes for the container [[ref]](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/) |
| mlflow.probes.livenessProbe | object | `{}` | Specify the liveness probes for the container |
| mlflow.probes.readinessProbe | object | `{}` | Specify the readiness probes for the container |
| mlflow.probes.startupProbe | object | `{}` | Specify the startup probes for the container |
| mlflow.replicas | int | `1` | Number of mlflow server replicas to deploy |
| mlflow.resources | object | `{}` | Set the resource requests / limits for the container. |
| mlflow.revisionHistoryLimit | string | `nil` | Deployment revision history limit |
| mlflow.rollingUpdate | object | `{"maxSurge":1,"maxUnavailable":1}` | Rolling update configuration |
| mlflow.rollingUpdate.maxSurge | int | `1` | The maximum number of pods that can be scheduled above the desired number of pods |
| mlflow.rollingUpdate.maxUnavailable | int | `1` | The maximum number of pods that can be unavailable during the update process |
| mlflow.runtimeClassName | string | `""` | Allow specifying a runtimeClassName other than the default one (ie: nvidia) |
| mlflow.schedulerName | string | `""` | Allows specifying a custom scheduler name |
| mlflow.service | object | `{"annotations":{},"name":"http","nodePort":"","port":5000,"type":"ClusterIP"}` | Mlflow Service configuration |
| mlflow.service.annotations | object | `{}` | Annotations to add to the service |
| mlflow.service.name | string | `"http"` | Service port name |
| mlflow.service.nodePort | string | `""` | Service Node port Used when the service type is NodePort or LoadBalancer |
| mlflow.service.port | int | `5000` | Service port number |
| mlflow.service.type | string | `"ClusterIP"` | Specifies which type of service should be created |
| mlflow.serviceAccount | object | `{"annotations":{},"create":true,"name":""}` | Service account configuration for the mlflow deployment |
| mlflow.serviceAccount.annotations | object | `{}` | Annotations to add to the service account if create is true |
| mlflow.serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| mlflow.serviceAccount.name | string | `""` | Name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| mlflow.strategy | string | `"RollingUpdate"` | Strategy to use to replace existing pods with new ones |
| mlflow.termination.gracePeriodSeconds | string | `nil` | [[ref](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#lifecycle)] |
| mlflow.termination.messagePath | string | `nil` | [[ref](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#lifecycle-1)] |
| mlflow.termination.messagePolicy | string | `nil` | [[ref](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#lifecycle-1)] |
| mlflow.tolerations | list | `[]` | Specify taint tolerations [[ref]](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) |
| mlflow.topologySpreadConstraints | list | `[]` | Defines topologySpreadConstraint rules. [[ref]](https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/) |
| mlflow.trackingServer.artifactsDestination | string | `"s3://mlflow"` | Specifies the base artifact location from which to resolve artifact upload/download/list requests (e.g. `s3://my-bucket`) |
| mlflow.trackingServer.basicAuth.createSecret.adminPassword | string | `"password"` | Default admin password if the admin is not already created |
| mlflow.trackingServer.basicAuth.createSecret.adminUsername | string | `"admin"` | Default admin username if the admin is not already created |
| mlflow.trackingServer.basicAuth.createSecret.authorizationFunction | string | `"mlflow.server.auth:authenticate_request_basic_auth"` | Function to authenticate requests |
| mlflow.trackingServer.basicAuth.createSecret.defaultPermission | string | `"READ"` | Default permission on all resources |
| mlflow.trackingServer.basicAuth.enabled | bool | `true` | Specifies whether to enable basic authentication |
| mlflow.trackingServer.basicAuth.existingSecret | string | `""` | Name of an existing secret which contains key `basic_auth.ini` |
| mlflow.trackingServer.defaultArtifactRoot | string | `""` | Specifies a default artifact location for logging, data will be logged to `mlflow-artifacts/:` if artifact serving is enabled, otherwise `./mlruns` |
| mlflow.trackingServer.extraArgs | list | `["--dev"]` | Extra arguments passed to the `mlflow server` command |
| mlflow.trackingServer.host | string | `"0.0.0.0"` | Network address to listen on |
| mlflow.trackingServer.mode | string | `"serve-artifacts"` | Specifies which mode mlflow tracking server run with, available options are `serve-artifacts`, `no-serve-artifacts` and `artifacts-only` |
| mlflow.trackingServer.port | int | `5000` | Port to expose the tracking server |
| mlflow.trackingServer.workers | int | `1` | Number of gunicorn worker processes to handle requests |
| nameOverride | string | `""` | String to override the default generated name |
| postgres | object | `{"auth":{"password":"mlflow","username":"mlflow"},"embedded":{"additionalLabels":{},"affinity":{},"annotations":{},"certificates":{},"enableSuperuserAccess":true,"enabled":true,"image":{"repository":"ghcr.io/cloudnative-pg/postgresql","tag":"15.2"},"imagePullPolicy":"IfNotPresent","imagePullSecrets":[],"initdb":{"database":"mlflow","owner":"mlflow","postInitApplicationSQL":[]},"instances":3,"logLevel":"info","podAntiAffinityMode":"soft","podAntiAffinityTopologyKey":"","postgresGID":26,"postgresUID":26,"postgresql":{},"primaryUpdateMethod":"switchover","primaryUpdateStrategy":"unsupervised","priorityClassName":"","resources":{},"roles":[],"storage":{"size":"10Gi","storageClass":""},"superuserSecret":"","type":"postgresql"},"external":{"database":"mlflow","enabled":false,"host":"","port":5432}}` | Embedded Postrgres configuration Deploys a cluster using the CloudnativePG Operator [[ref]](https://github.com/cloudnative-pg/cloudnative-pg) |
| postgres.auth | object | `{"password":"mlflow","username":"mlflow"}` | Postgres authentication configuration |
| postgres.auth.password | string | `"mlflow"` | Mlflow Tracking Server Postgres password |
| postgres.auth.username | string | `"mlflow"` | Mlflow Tracking Server Postgres username |
| postgres.embedded.additionalLabels | object | `{}` | Addtional labels for Postgres cluster |
| postgres.embedded.affinity | object | `{}` | Affinity/Anti-affinity rules for Pods. See: https://cloudnative-pg.io/documentation/current/cloudnative-pg.v1/#postgresql-cnpg-io-v1-AffinityConfiguration |
| postgres.embedded.annotations | object | `{}` | Postgres cluster annotations |
| postgres.embedded.certificates | object | `{}` | The configuration for the CA and related certificates. See: https://cloudnative-pg.io/documentation/current/cloudnative-pg.v1/#postgresql-cnpg-io-v1-CertificatesConfiguration |
| postgres.embedded.enableSuperuserAccess | bool | `true` | When this option is enabled, the operator will use the SuperuserSecret to update the postgres user password. If the secret is not present, the operator will automatically create one. When this option is disabled, the operator will ignore the SuperuserSecret content, delete it when automatically created, and then blank the password of the postgres user by setting it to NULL. |
| postgres.embedded.enabled | bool | `true` | Specifies whether to enable the Embedded Postrgres cluster |
| postgres.embedded.image.repository | string | `"ghcr.io/cloudnative-pg/postgresql"` | Image registry |
| postgres.embedded.image.tag | string | `"15.2"` | Image tag |
| postgres.embedded.imagePullPolicy | string | `"IfNotPresent"` | Image pull policy |
| postgres.embedded.imagePullSecrets | list | `[]` | Image pull secrets |
| postgres.embedded.initdb | object | `{"database":"mlflow","owner":"mlflow","postInitApplicationSQL":[]}` | Postgres InitDB configuration |
| postgres.embedded.initdb.database | string | `"mlflow"` | Postgres database name to be initilized |
| postgres.embedded.initdb.owner | string | `"mlflow"` | Postgres username name to be initilized |
| postgres.embedded.initdb.postInitApplicationSQL | list | `[]` | Postgres init application SQL |
| postgres.embedded.instances | int | `3` | Number of Postgres instances to deploy |
| postgres.embedded.logLevel | string | `"info"` | Postgres log level |
| postgres.embedded.podAntiAffinityMode | string | `"soft"` | Specifies whether podAntiAffinity should be "required" or simply "preferred" This determines if requiredDuringSchedulingIgnoredDuringExecution or preferredDuringSchedulingIgnoredDuringExecution is used [[ref]](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity) |
| postgres.embedded.podAntiAffinityTopologyKey | string | `""` | Enables podAntiAffinity with the specified topology key .postgres.embedded.affinity takes precedence over this setting |
| postgres.embedded.postgresGID | int | `26` | Postgres GID |
| postgres.embedded.postgresUID | int | `26` | Postgres UID |
| postgres.embedded.postgresql | object | `{}` | Configuration of the PostgreSQL server. See: https://cloudnative-pg.io/documentation/current/cloudnative-pg.v1/#postgresql-cnpg-io-v1-PostgresConfiguration |
| postgres.embedded.primaryUpdateMethod | string | `"switchover"` | Postgres primary update method |
| postgres.embedded.primaryUpdateStrategy | string | `"unsupervised"` | Postgres primary update strategy |
| postgres.embedded.priorityClassName | string | `""` | Postgres priority class name |
| postgres.embedded.resources | object | `{}` | Postgres resources |
| postgres.embedded.roles | list | `[]` | This feature enables declarative management of existing roles, as well as the creation of new roles if they are not already present in the database. See: https://cloudnative-pg.io/documentation/current/declarative_role_management/ |
| postgres.embedded.storage | object | `{"size":"10Gi","storageClass":""}` | Postgres storage configuration |
| postgres.external.database | string | `"mlflow"` | External Postgres database |
| postgres.external.enabled | bool | `false` | Specifies whether to use an external PostgresSQL cluster NOTE: If you enabled External PostgreSQL, you should disable the Embedded PostgreSQL (cluster.enabled: false) |
| postgres.external.host | string | `""` | External Postgres host |
| postgres.external.port | int | `5432` | External Postgres port |
| replicated.enabled | bool | `true` | Specifies whetherto enable the Replicated SDK |

