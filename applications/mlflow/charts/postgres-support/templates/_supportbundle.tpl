{{- define "postgres-support.supportbundle" -}}
apiVersion: troubleshoot.sh/v1beta2
kind: SupportBundle
metadata:
  name: postgres-supportbundle
spec:
  collectors:
    - logs:
        name: cnpg-operator-logs
        namespace: {{ .Release.Namespace }}
        selector:
          - app.kubernetes.io/name=cloudnative-pg
        limits:
          maxAge: 720h
          maxLines: 10000
    - logs:
        name: postgres-cluster-logs
        namespace: {{ .Release.Namespace }}
        selector:
          - cnpg.io/cluster
        limits:
          maxAge: 720h
          maxLines: 10000
    - exec:
        name: pg-isready-check
        namespace: {{ .Release.Namespace }}
        selector:
          - cnpg.io/cluster
          - role=primary
        command: ["pg_isready"]
        args: ["-U", "postgres"]
        timeout: 10s
    - exec:
        name: cnpg-cluster-status
        namespace: {{ .Release.Namespace }}
        selector:
          - cnpg.io/cluster
          - role=primary
        command: ["psql"]
        args:
          - "-U"
          - "postgres"
          - "-c"
          - "SELECT version(); SELECT pg_is_in_recovery(); SELECT count(*) AS active_connections FROM pg_stat_activity;"
        timeout: 10s
    - clusterResources: {}
    - copy:
        name: postgres-config
        namespace: {{ .Release.Namespace }}
        selector:
          - cnpg.io/cluster
          - role=primary
        containerPath: /controller/run.json
        containerName: postgres
  analyzers:
    - textAnalyze:
        checkName: CloudnativePG Operator Running
        fileName: cnpg-operator-logs/*.log
        regex: "Starting manager"
        outcomes:
          - pass:
              when: "true"
              message: CloudnativePG operator is running
          - fail:
              when: "false"
              message: CloudnativePG operator may not be running - check operator pod logs
    - textAnalyze:
        checkName: PostgreSQL Accepting Connections
        fileName: pg-isready-check/*/pg_isready-*.txt
        regex: "accepting connections"
        outcomes:
          - pass:
              when: "true"
              message: PostgreSQL is accepting connections
          - fail:
              when: "false"
              message: PostgreSQL is not accepting connections - check cluster pod logs
    - textAnalyze:
        checkName: PostgreSQL Not in Recovery
        fileName: cnpg-cluster-status/*/psql-*.txt
        regex: "pg_is_in_recovery.*f"
        outcomes:
          - pass:
              when: "true"
              message: Primary PostgreSQL instance is not in recovery mode
          - warn:
              when: "false"
              message: Primary PostgreSQL instance may be in recovery mode
    - textAnalyze:
        checkName: PostgreSQL WAL Errors
        fileName: postgres-cluster-logs/*.log
        regex: "FATAL|PANIC|could not write to WAL"
        outcomes:
          - fail:
              when: "true"
              message: PostgreSQL logs contain FATAL/PANIC errors or WAL write failures
          - pass:
              when: "false"
              message: No critical PostgreSQL errors detected in logs
    - textAnalyze:
        checkName: CNPG Failover Events
        fileName: cnpg-operator-logs/*.log
        regex: "Initiating failover|failover completed"
        outcomes:
          - warn:
              when: "true"
              message: CloudnativePG failover events detected - review operator logs for details
          - pass:
              when: "false"
              message: No failover events detected
{{- end -}}
