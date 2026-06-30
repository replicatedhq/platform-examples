{{- define "license-validation.preflight" -}}
apiVersion: troubleshoot.sh/v1beta2
kind: Preflight
metadata:
  name: license-validation
spec:
  collectors:
    - clusterInfo: {}
    - clusterResources: {}
  analyzers:
    - clusterVersion:
        outcomes:
          - fail:
              when: "< 1.25.0"
              message: Requires Kubernetes 1.25.0 or later.
              uri: https://kubernetes.io
          - pass:
              message: Kubernetes version is compatible.
    - nodeResources:
        checkName: Cluster has sufficient memory
        outcomes:
          - fail:
              when: "sum(memoryCapacity) < 512Mi"
              message: At least 512Mi of memory is required.
          - pass:
              message: Sufficient memory available.
    - nodeResources:
        checkName: Cluster has sufficient CPU
        outcomes:
          - fail:
              when: "sum(cpuCapacity) < 1"
              message: At least 1 CPU core is required.
          - pass:
              message: Sufficient CPU available.
{{- end }}
