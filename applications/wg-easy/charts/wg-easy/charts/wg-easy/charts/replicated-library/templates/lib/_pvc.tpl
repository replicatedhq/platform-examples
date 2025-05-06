{{/*
This template serves as a blueprint for all PersistentVolumeClaim objects that are created
within the replicated-library library.
*/}}
{{- define "replicated-library.classes.pvc" -}}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "persistence") -}}
    {{- $values = .ContextValues.persistence -}}
  {{- else -}}
    {{- fail "_persistence.tpl requires the 'persistence' ContextValues to be set" -}}
  {{- end -}}
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  {{- $_ := set $.ContextValues "names" (dict "context" "persistence") }}
  name: {{ include "replicated-library.names.fullname" . }}
  {{- $_ := unset $.ContextValues "names" }}
  {{- with (merge ($values.labels | default dict) (include "replicated-library.labels" $ | fromYaml)) }}
  labels: {{- toYaml . | nindent 4 }}
  {{- end }}
  annotations:
    {{- with (merge ($values.annotations | default dict) (include "replicated-library.annotations" $ | fromYaml)) }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- with $values.persistentVolumeClaim.spec }}
spec:
    {{- toYaml . | nindent 4 }}
{{- end }}
{{- end -}}
