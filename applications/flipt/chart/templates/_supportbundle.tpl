{{- define "flipt.supportbundle" -}}
apiVersion: troubleshoot.sh/v1beta2
kind: SupportBundle
metadata:
  name: flipt-support-bundle
spec:
  collectors:
    # Cluster information
    - clusterInfo: {}
    - clusterResources: {}

    # Flipt application logs
    - logs:
        selector:
          - app.kubernetes.io/name=flipt
        namespace: "{{ .Release.Namespace }}"
        limits:
          maxAge: 720h
          maxLines: 10000
        name: flipt/logs

    # PostgreSQL logs (embedded)
    - logs:
        selector:
          - cnpg.io/cluster={{ .Release.Name }}-cluster
        namespace: "{{ .Release.Namespace }}"
        limits:
          maxAge: 720h
          maxLines: 10000
        name: postgresql/logs

    # CloudnativePG operator logs
    - logs:
        selector:
          - app.kubernetes.io/name=cloudnative-pg
        namespace: "{{ .Release.Namespace }}"
        limits:
          maxAge: 720h
          maxLines: 10000
        name: cnpg-operator/logs

    # Valkey logs
    - logs:
        selector:
          - app.kubernetes.io/name=valkey
        namespace: "{{ .Release.Namespace }}"
        limits:
          maxAge: 720h
          maxLines: 10000
        name: valkey/logs

    # Pod status and events
    - pods:
        namespace: "{{ .Release.Namespace }}"
        selector:
          - app.kubernetes.io/name=flipt

    - pods:
        namespace: "{{ .Release.Namespace }}"
        selector:
          - cnpg.io/cluster={{ .Release.Name }}-cluster

    - pods:
        namespace: "{{ .Release.Namespace }}"
        selector:
          - app.kubernetes.io/name=cloudnative-pg

    - pods:
        namespace: "{{ .Release.Namespace }}"
        selector:
          - app.kubernetes.io/name=valkey

    # Service and endpoint information
    - services:
        namespace: "{{ .Release.Namespace }}"

    - endpoints:
        namespace: "{{ .Release.Namespace }}"

    # ConfigMaps and Secrets (redacted)
    - configMaps:
        namespace: "{{ .Release.Namespace }}"

    - secrets:
        namespace: "{{ .Release.Namespace }}"
        includeKeys:
          - false

    # PVC and storage information
    - pvcs:
        namespace: "{{ .Release.Namespace }}"

    # Ingress configuration
    - ingress:
        namespace: "{{ .Release.Namespace }}"

    # PostgreSQL specific diagnostics
    - exec:
        name: postgresql-version
        selector:
          - cnpg.io/cluster={{ .Release.Name }}-cluster
        namespace: "{{ .Release.Namespace }}"
        command: ["psql"]
        args: ["-c", "SELECT version();"]
        timeout: 30s

    - exec:
        name: postgresql-connections
        selector:
          - cnpg.io/cluster={{ .Release.Name }}-cluster
        namespace: "{{ .Release.Namespace }}"
        command: ["psql"]
        args: ["-c", "SELECT count(*) as connections FROM pg_stat_activity;"]
        timeout: 30s

    - exec:
        name: postgresql-database-size
        selector:
          - cnpg.io/cluster={{ .Release.Name }}-cluster
        namespace: "{{ .Release.Namespace }}"
        command: ["psql"]
        args: ["-c", "SELECT pg_size_pretty(pg_database_size('flipt')) as database_size;"]
        timeout: 30s

    # Valkey diagnostics
    - exec:
        name: valkey-info
        selector:
          - app.kubernetes.io/name=valkey
        namespace: "{{ .Release.Namespace }}"
        command: ["valkey-cli"]
        args: ["INFO"]
        timeout: 30s

    - exec:
        name: valkey-memory
        selector:
          - app.kubernetes.io/name=valkey
        namespace: "{{ .Release.Namespace }}"
        command: ["valkey-cli"]
        args: ["INFO", "memory"]
        timeout: 30s

    # Flipt API health check
    - http:
        name: flipt-health
        get:
          url: http://{{ .Release.Name }}.{{ .Release.Namespace }}.svc.cluster.local:8080/health
        timeout: 30s

    # Helm release information
    - exec:
        name: helm-values
        selector:
          - app.kubernetes.io/name=flipt
        namespace: "{{ .Release.Namespace }}"
        command: ["sh"]
        args: ["-c", "helm get values {{ .Release.Name }} -n {{ .Release.Namespace }}"]
        timeout: 30s

    - exec:
        name: helm-manifest
        selector:
          - app.kubernetes.io/name=flipt
        namespace: "{{ .Release.Namespace }}"
        command: ["sh"]
        args: ["-c", "helm get manifest {{ .Release.Name }} -n {{ .Release.Namespace }}"]
        timeout: 30s

    # Node information
    - nodeMetrics: {}

    # Storage class information
    - storageClasses: {}

    # Network diagnostics
    - exec:
        name: flipt-to-postgres-connectivity
        selector:
          - app.kubernetes.io/name=flipt
        namespace: "{{ .Release.Namespace }}"
        command: ["sh"]
        args: ["-c", "nc -zv {{ .Release.Name }}-cluster-rw 5432 || echo 'Cannot connect to PostgreSQL'"]
        timeout: 10s

    - exec:
        name: flipt-to-valkey-connectivity
        selector:
          - app.kubernetes.io/name=flipt
        namespace: "{{ .Release.Namespace }}"
        command: ["sh"]
        args: ["-c", "nc -zv {{ .Release.Name }}-valkey-svc 6379 || echo 'Cannot connect to Valkey'"]
        timeout: 10s

  analyzers:
    # Pod status analysis
    - deploymentStatus:
        name: flipt
        namespace: "{{ .Release.Namespace }}"
        outcomes:
          - fail:
              when: "< 1"
              message: Flipt deployment has no ready replicas
          - warn:
              when: "< {{ .Values.replicaCount | default 1 }}"
              message: Flipt deployment has fewer replicas than configured
          - pass:
              message: Flipt deployment is healthy

    # PostgreSQL cluster health
    - clusterPodStatuses:
        name: postgresql-cluster-health
        namespace: "{{ .Release.Namespace }}"
        outcomes:
          - fail:
              when: "!= Healthy"
              message: PostgreSQL cluster is not healthy
          - pass:
              message: PostgreSQL cluster is healthy

    # Valkey health
    - deploymentStatus:
        name: flipt-valkey
        namespace: "{{ .Release.Namespace }}"
        outcomes:
          - fail:
              when: "< 1"
              message: Valkey deployment has no ready replicas
          - pass:
              message: Valkey is healthy

    # Node resources
    - nodeResources:
        checkName: Node CPU capacity
        outcomes:
          - warn:
              when: "sum(cpuCapacity) < 2"
              message: Less than 2 CPU cores available. Consider scaling cluster for production workloads.
          - pass:
              message: Sufficient CPU resources

    - nodeResources:
        checkName: Node memory capacity
        outcomes:
          - warn:
              when: "sum(memoryCapacity) < 4Gi"
              message: Less than 4GB memory available. Consider scaling cluster for production workloads.
          - pass:
              message: Sufficient memory resources

    # HTTP health check analysis
    - textAnalyze:
        checkName: Flipt API health
        fileName: flipt-health/result.json
        regex: '"status": "SERVING"'
        outcomes:
          - fail:
              when: "false"
              message: Flipt API health check failed
          - pass:
              when: "true"
              message: Flipt API is healthy
{{- end -}}
