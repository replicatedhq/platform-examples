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
          maxAge: 168h
          maxLines: 10000
        name: postgresql/logs

    # Valkey logs
    - logs:
        selector:
          - app.kubernetes.io/name=valkey
        namespace: "{{ .Release.Namespace }}"
        limits:
          maxAge: 168h
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
          url: http://{{ .Release.Name }}-flipt.{{ .Release.Namespace }}.svc.cluster.local:8080/health
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
        name: flipt-deployment
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
        name: valkey-health
        namespace: "{{ .Release.Namespace }}"
        outcomes:
          - fail:
              when: "< 1"
              message: Valkey deployment has no ready replicas
          - pass:
              message: Valkey is healthy

    # Storage analysis
    - textAnalyze:
        checkName: Persistent Volume Claims
        fileName: /cluster-resources/persistent-volume-claims.json
        regexGroups: '"phase": "(\w+)"'
        outcomes:
          - fail:
              when: "Pending"
              message: One or more PVCs are in Pending state
          - fail:
              when: "Failed"
              message: One or more PVCs have failed
          - pass:
              when: "Bound"
              message: All PVCs are bound

    # Node resources
    - nodeResources:
        checkName: Node CPU capacity
        outcomes:
          - warn:
              when: "sum(cpuCapacity) < 4"
              message: Less than 4 CPU cores available. Consider scaling cluster for production workloads.
          - pass:
              message: Sufficient CPU resources

    - nodeResources:
        checkName: Node memory capacity
        outcomes:
          - warn:
              when: "sum(memoryCapacity) < 8Gi"
              message: Less than 8GB memory available. Consider scaling cluster for production workloads.
          - pass:
              message: Sufficient memory resources

    # Log analysis for common errors
    - textAnalyze:
        checkName: Check for database connection errors
        fileName: flipt/logs/*.log
        regex: 'database connection|connection refused|could not connect'
        outcomes:
          - fail:
              when: "true"
              message: Database connection errors detected in logs
          - pass:
              message: No database connection errors found

    - textAnalyze:
        checkName: Check for Valkey connection errors
        fileName: flipt/logs/*.log
        regex: 'redis.*error|valkey.*error|ECONNREFUSED.*(redis|valkey)|(redis|valkey).*timeout'
        outcomes:
          - warn:
              when: "true"
              message: Valkey connection errors detected. Check Valkey connectivity.
          - pass:
              message: No Valkey connection errors found

    - textAnalyze:
        checkName: Check for OOM errors
        fileName: flipt/logs/*.log
        regex: 'out of memory|OOMKilled|memory limit exceeded'
        outcomes:
          - fail:
              when: "true"
              message: Out of memory errors detected. Consider increasing memory limits.
          - pass:
              message: No OOM errors detected

    # HTTP health check analysis
    - textAnalyze:
        checkName: Flipt API health
        fileName: http-response/flipt-health.json
        regex: '"status": "ok"'
        outcomes:
          - fail:
              when: "false"
              message: Flipt API health check failed
          - pass:
              when: "true"
              message: Flipt API is healthy
{{- end -}}
