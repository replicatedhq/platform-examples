{{/*
This template serves as a blueprint for all configMap objects that are created
within the replicated-library library.
*/}}
{{- define "replicated-library.configmap" -}}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "configmap") -}}
    {{- $values = .ContextValues.configmap -}}
  {{- else -}}
    {{- fail "_configmap.tpl requires the 'configmap' ContextValues to be set" -}}
  {{- end -}}
  {{- $_ := set $.ContextValues "names" (dict "context" "configmap") -}}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "replicated-library.names.fullname" . }}
  {{- with (merge ($values.labels | default dict) (include "replicated-library.labels" $ | fromYaml)) }}
  labels: {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (merge ($values.annotations | default dict) (include "replicated-library.annotations" $ | fromYaml)) }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
data:
{{- with $values.data }}
  {{- tpl (toYaml .) $ | nindent 2 }}
{{- end }}
{{- end }}
