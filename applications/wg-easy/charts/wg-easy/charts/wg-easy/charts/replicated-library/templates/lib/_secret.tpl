{{/*
This template serves as a blueprint for all secret objects that are created
within the replicated-library library.
*/}}
{{- define "replicated-library.classes.secret" -}}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "secret") -}}
    {{- $values = .ContextValues.secret -}}
  {{- else -}}
    {{- fail "_secret.tpl requires the 'secret' ContextValues to be set" -}}
  {{- end -}}
  {{- $_ := set $.ContextValues "names" (dict "context" "secret") -}}
---
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "replicated-library.names.fullname" . }}
  {{- with (merge ($values.labels | default dict) (include "replicated-library.labels" $ | fromYaml)) }}
  labels: {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (merge ($values.annotations | default dict) (include "replicated-library.annotations" $ | fromYaml)) }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
stringData:
{{- with $values.data }}
  {{- tpl (toYaml .) $ | nindent 2 }}
{{- end }}
type: {{ $values.type }}
{{- end }}
