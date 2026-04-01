{{- define "license-validation.supportbundle" -}}
apiVersion: troubleshoot.sh/v1beta2
kind: SupportBundle
metadata:
  name: license-validation
spec:
  collectors:
    - clusterResources:
        namespaces:
          - {{ .Release.Namespace }}
    - logs:
        name: license-validation-logs
        namespace: {{ .Release.Namespace }}
        selector:
          - app.kubernetes.io/name={{ include "license-validation.name" . }}
  analyzers:
    - deploymentStatus:
        name: license-validation
        namespace: {{ .Release.Namespace }}
        outcomes:
          - fail:
              when: "< 1"
              message: The license-validation deployment has no ready replicas.
          - pass:
              message: The license-validation deployment is running.
{{- end }}
