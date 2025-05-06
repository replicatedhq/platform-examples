{{- define "replicated-library.troubleshoot.analyzer.general" -}}
- {{ .ContextNames.analyzer }}:
  {{- if .ContextValues.analyzer }}
  {{- .ContextValues.analyzer | toYaml | nindent 4}}
  {{- else -}}
  {{ "{}" | indent 1 }}
  {{- end }}
{{- end }}