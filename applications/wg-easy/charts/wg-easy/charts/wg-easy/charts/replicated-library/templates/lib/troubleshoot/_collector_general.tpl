{{- define "replicated-library.troubleshoot.collector.general" -}}
- {{ .ContextNames.collector }}:
  {{- with .ContextValues.collector }}
    {{- . | toYaml | nindent 4 }}
  {{- else -}}
    {{ "{}" | indent 1 }}
  {{- end }}
{{- end }}
