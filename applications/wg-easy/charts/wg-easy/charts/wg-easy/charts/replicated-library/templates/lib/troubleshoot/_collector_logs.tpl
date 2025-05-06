{{- define "replicated-library.troubleshoot.collector.logs" -}}
- {{ .ContextNames.collector }}:
  {{- with .ContextValues.collector }}
  {{- if eq .appName "*" }}
    selector:
      - app.kubernetes.io/name={{ include "replicated-library.names.name" $ }}
      - app.kubernetes.io/instance={{ $.Release.Name }}
  {{- else if .appName }}
    {{- if index $.Values.apps .appName }}
      {{- $_ := set $.ContextNames "app" .appName }}
    selector:
      {{- range (include "replicated-library.labels.selectorLabels" $ | splitList "\n" ) }}
      {{- printf "- %s" . | replace ": " "=" | nindent 6 }}
      {{- end }}
      {{- $_ := unset $.ContextNames "app" }}
    {{- else }}
      {{- fail (printf "Matching app for AppName (%s) was not found" .appName) }}
    {{- end }}
  {{- else if .selector }}
    selector:
      {{- .selector | toYaml | nindent 6}}
  {{- else }}
    {{- fail (printf "Either 'selector', or 'appName' were found for the 'logs' collector.") }}
  {{- end }}

  {{- if .collectorName }}
    collectorName: {{ .collectorName }}
  {{- end }}

  {{- if .name }}
    name: {{ .name }}
  {{- else -}}
    {{- fail (printf "The 'name' for the 'logs' collector was not found.") }}
  {{- end }}

  {{- if .containerNames }}
    containerNames:
      {{- range .containerNames }}
    - {{ . }}
      {{- end }}
  {{- end }}

  {{- if .limits }}
    limits:
      maxAge: {{ default "720h" .limits.maxAge }}
      maxLines: {{ default 10000 .limits.maxLines }}
      maxBytes: {{ default 5000000 .limits.maxBytes }}
  {{- end }}

  {{- if .namespace }}
    namespace: {{ .namespace }}
  {{- else }}
    namespace: {{ $.Release.Namespace }}
  {{- end }}

  {{- end }}

{{- end }}
