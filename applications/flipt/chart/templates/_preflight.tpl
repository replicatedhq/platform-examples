{{- define "flipt.preflight" -}}
apiVersion: troubleshoot.sh/v1beta2
kind: Preflight
metadata:
  name: flipt-preflight-checks
spec:
  analyzers:
    # Kubernetes version check
    - clusterVersion:
        outcomes:
          - fail:
              when: "< 1.24.0"
              message: Flipt requires Kubernetes 1.24.0 or later
              uri: https://kubernetes.io/releases/
          - warn:
              when: "< 1.27.0"
              message: Kubernetes 1.27.0 or later is recommended for best performance
          - pass:
              when: ">= 1.27.0"
              message: Kubernetes version is supported

    # Node resource checks
    - nodeResources:
        checkName: Minimum CPU cores available
        outcomes:
          - fail:
              when: "sum(cpuCapacity) < 2"
              message: The cluster must have at least 2 CPU cores available
          - warn:
              when: "sum(cpuCapacity) < 4"
              message: At least 4 CPU cores are recommended for production
          - pass:
              message: Sufficient CPU resources available

    - nodeResources:
        checkName: Minimum memory available
        outcomes:
          - fail:
              when: "sum(memoryCapacity) < 4Gi"
              message: The cluster must have at least 4GB of memory available
          - warn:
              when: "sum(memoryCapacity) < 8Gi"
              message: At least 8GB of memory is recommended for production
          - pass:
              message: Sufficient memory available

    # Storage checks
    - storageClass:
        checkName: Default storage class
        storageClassName: ""
        outcomes:
          - fail:
              message: No default storage class found. A default storage class is required.
              uri: https://kubernetes.io/docs/concepts/storage/storage-classes/
          - pass:
              message: Default storage class is available

    - storageClass:
        checkName: Storage class with RWO support
        storageClassName: ""
        outcomes:
          - fail:
              message: The storage class does not support ReadWriteOnce access mode
          - pass:
              message: Storage class supports required access modes

    # Database specific checks (for embedded PostgreSQL)
    - nodeResources:
        checkName: PostgreSQL resource requirements
        outcomes:
          - fail:
              when: "sum(memoryCapacity) < 2Gi"
              message: |
                At least 2GB of memory is required for embedded PostgreSQL.
                Consider using an external database if cluster resources are limited.
          - warn:
              when: "sum(cpuCapacity) < 2"
              message: At least 2 CPU cores recommended for embedded PostgreSQL
          - pass:
              message: Sufficient resources for embedded PostgreSQL

    # Redis specific checks
    - nodeResources:
        checkName: Redis resource requirements
        outcomes:
          - warn:
              when: "sum(memoryCapacity) < 1Gi"
              message: |
                At least 1GB of memory recommended for Redis cache.
                Consider using in-memory caching if Redis is disabled.
          - pass:
              message: Sufficient resources for Redis cache

    # Network checks
    - customResourceDefinition:
        checkName: Check for Ingress Controller
        customResourceDefinitionName: ingressclasses.networking.k8s.io
        outcomes:
          - fail:
              message: |
                No ingress controller detected in the cluster.
                An ingress controller (like NGINX or Traefik) is required if ingress is enabled.
          - pass:
              message: Ingress controller CRDs are available

    # CloudnativePG operator check (for embedded database)
    - customResourceDefinition:
        checkName: CloudnativePG Operator
        customResourceDefinitionName: clusters.postgresql.cnpg.io
        outcomes:
          - warn:
              message: |
                CloudnativePG operator is not installed.
                The operator will be installed as part of this deployment.
                If you prefer to use an external PostgreSQL database, configure it in the admin console.
          - pass:
              message: CloudnativePG operator is available

    # Image pull checks
    - imagePullSecret:
        checkName: Registry access
        registryName: docker.flipt.io
        outcomes:
          - fail:
              message: |
                Cannot pull images from docker.flipt.io.
                Check network connectivity or configure image pull secrets.
          - pass:
              message: Can pull images from container registry

    # Distribution-specific checks
    - distribution:
        outcomes:
          - fail:
              when: "== docker-desktop"
              message: |
                Docker Desktop is not recommended for production deployments.
                Use a production-grade Kubernetes distribution.
          - warn:
              when: "== kind"
              message: |
                kind is detected. This is suitable for development only.
          - warn:
              when: "== minikube"
              message: |
                Minikube is detected. This is suitable for development only.
          - pass:
              message: Kubernetes distribution is suitable for Flipt deployment

    # Cluster resource capacity
    - deploymentStatus:
        checkName: Cluster is healthy
        namespace: kube-system
        name: coredns
        outcomes:
          - fail:
              when: "absent"
              message: CoreDNS is not running. The cluster may not be healthy.
          - fail:
              when: "!= Healthy"
              message: CoreDNS deployment is not healthy
          - pass:
              message: Cluster DNS is healthy

  collectors:
    - clusterInfo: {}
    - clusterResources: {}
    - logs:
        selector:
          - app=flipt
        namespace: {{ .Values.namespace | default "flipt" | quote }}
        limits:
          maxAge: 720h
          maxLines: 10000
    - exec:
        name: kubectl-version
        selector:
          - app=flipt
        namespace: {{ .Values.namespace | default "flipt" | quote }}
        command: ["kubectl"]
        args: ["version", "--short"]
        timeout: 30s
{{- end -}}
