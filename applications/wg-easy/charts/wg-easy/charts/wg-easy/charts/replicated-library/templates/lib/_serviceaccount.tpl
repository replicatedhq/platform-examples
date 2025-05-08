{{/*
The ServiceAccount object to be created.
*/}}
{{- define "replicated-library.serviceAccount" }}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "serviceAccount") -}}
    {{- $values = .ContextValues.serviceAccount -}}
  {{- else -}}
    {{- fail "_serviceaccount.tpl requires the 'serviceAccount' ContextValues to be set" -}}
  {{- end -}}
  {{- $_ := set $.ContextValues "names" (dict "context" "serviceAccount") -}}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "replicated-library.names.fullname" . }}
  {{- with (merge ($values.labels | default dict) (include "replicated-library.labels" $ | fromYaml)) }}
  labels: {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (merge ($values.annotations | default dict) (include "replicated-library.annotations" $ | fromYaml)) }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
