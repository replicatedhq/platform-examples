{{- define "replicated-library.troubleshoot.collector.data" -}}
- {{ .ContextNames.collector }}:
  {{- with .ContextValues.collector }}
    {{- if .collectorName }}
    collectorName: {{ .collectorName }}
    {{- end }}

    {{- if .name }}
    name: {{ .name }}
    {{- end }}

    {{- if .data }}
    data: {{ .data }}
    {{- else }}
      {{- fail (printf "The 'data' for the 'data' collector was not found." ) }}
    {{- end }}

  {{- end }}
{{- end }}
