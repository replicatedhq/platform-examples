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
        name: cnpg-cluster-status
        namespace: {{ .Release.Namespace }}
        selector:
          - cnpg.io/cluster
        command: ["pg_isready"]
        args: ["-U", "postgres"]
        timeout: 10s
    - clusterResources:
        name: cnpg-clusters
    - clusterResources:
        name: postgres-pvcs
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
              message: CloudnativePG operator may not be running — check operator pod logs
    - textAnalyze:
        checkName: PostgreSQL Cluster Healthy
        fileName: postgres-cluster-logs/*.log
        regex: "database system is ready to accept connections"
        outcomes:
          - pass:
              when: "true"
              message: PostgreSQL cluster is accepting connections
          - fail:
              when: "false"
              message: PostgreSQL cluster may not be healthy — check cluster pod logs
    - textAnalyze:
        checkName: PostgreSQL Ready Check
        fileName: cnpg-cluster-status/*/pg_isready-*.txt
        regex: "accepting connections"
        outcomes:
          - pass:
              when: "true"
              message: PostgreSQL is accepting connections
          - fail:
              when: "false"
              message: PostgreSQL is not accepting connections
{{- end -}}
