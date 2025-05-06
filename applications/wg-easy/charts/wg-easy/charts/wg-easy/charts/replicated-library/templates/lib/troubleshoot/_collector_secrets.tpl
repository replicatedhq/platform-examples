{{- define "replicated-library.troubleshoot.collector.secret" -}}
- {{ .ContextNames.collector }}:
  {{- with .ContextValues.collector }}
  {{- if eq .secretName "*" -}}
    selector:
      - app.kubernetes.io/name={{ include "replicated-library.names.name" . }}
      - app.kubernetes.io/instance={{ .Release.Name }}
  {{- else if .secretName -}}
    name: {{ .secretName }}
  {{- else if .selector -}}
    selector:
      {{- .selector | toYaml | nindent 6}}
  {{- else if .name }}
    name: {{ .name }}
  {{- else }}
    {{- fail (printf "Neither 'selector', 'name', nor 'secretName' were found for the 'secret' collector." .) }}
  {{- end }}

  {{- if .collectorName }}
    collectorName: {{ .collectorName }}
  {{- end }}

  {{- if .namespace }}
    namespace: {{ .namespace }}
  {{- else }}
    namespace: {{ $.Release.Namespace }}
  {{- end }}

  {{- if .key }}
    key: {{ .key }}
  {{- end }}

  {{- end }}

{{- end }}
