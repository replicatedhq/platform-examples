{{- define "replicated-library.troubleshoot.collector.configMap" -}}
- {{ .ContextNames.collector }}:
  {{- with .ContextValues.collector }}
  {{- if eq .configMapName "*" }}
    selector:
      - app.kubernetes.io/name={{ include "replicated-library.names.name" $ }}
      - app.kubernetes.io/instance={{ $.Release.Name }}
  {{- else if .configMapName }}
    name: {{ .configMapName }}
  {{- else if .selector }}
    selector:
      {{- .selector | toYaml | nindent 6}}
  {{- else if .name }}
    name: {{ .name }}
  {{- else }}
    {{- fail (printf "Neither 'selector', 'name', nor 'configMapName' were found for the 'configMap' collector." .) }}
  {{- end }}

  {{- if .collectorName }}
    collectorName: {{ .collectorName }}
  {{- end }}

  {{- if .namespace }}
    namespace: {{ .namespace }}
  {{- else }}
    namespace: {{ $.Release.Namespace }}
  {{- end }}

  {{- if .includeValue }}
    includeValue: {{ .includeValue }}
  {{- end }}

  {{- if .key }}
    key: {{ .key }}
  {{- end }}

  {{- if .includeAllData }}
    includeAllData: {{ .includeAllData }}
  {{- end }}
  
  {{- end }}

{{- end }}
