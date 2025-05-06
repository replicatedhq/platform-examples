{{/*
This template serves as the blueprint for a Role object created
within the replicated-library library.
*/}}
{{- define "replicated-library.role" }}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "role") -}}
    {{- $values = .ContextValues.role -}}
  {{- else -}}
    {{- fail "_role.tpl requires the 'role' ContextValues to be set" -}}
  {{- end -}}
  {{- $_ := set $.ContextValues "names" (dict "context" "role") -}}
---
apiVersion: rbac.authorization.k8s.io/v1
  {{- $kind := default "Role" $values.kind -}}
  {{- if and (ne $kind "Role") (ne $kind "ClusterRole") -}}
    {{- fail (printf "Not a valid kind of Role (%s); must be Role or ClusterRole" $kind) -}}
  {{- end }}
kind: {{ $kind }}
metadata:
  name: {{ include "replicated-library.names.fullname" . }}
  {{- with (merge ($values.labels | default dict) (include "replicated-library.labels" $ | fromYaml)) }}
  labels: {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (merge ($values.annotations | default dict) (include "replicated-library.annotations" $ | fromYaml)) }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if $values.aggregationRule }}
    {{- if ne $kind "ClusterRole" }}
      {{- fail (printf "If aggregation rules are set, role must be a ClusterRole") -}}
    {{- end }}
  aggregationRule:
    clusterRoleSelectors:
    {{- with $values.aggregationRule.clusterRoleSelectors }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- if $values.rules }}
rules:
    {{- with $values.rules -}}
      {{- toYaml . | nindent 2 }}
    {{- end }}
  {{- end }}
{{- end }}
