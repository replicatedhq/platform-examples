{{- define "replicated-library.troubleshoot.collector.exec" -}}
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
    {{- fail (printf "Either 'selector', or 'appName' were found for the 'exec' collector.") }}
  {{- end }}

  {{- if .command }}
    {{- range .command }}
      - {{ . }}
    {{- end }}
  {{- else -}}
    {{- fail (printf "The 'command' for the 'exec' collector was not found.") }}
  {{- end }}

  {{- if .collectorName }}
    collectorName: {{ .collectorName }}
  {{- end }}

  {{- if .name }}
    name: {{ .name }}
  {{- end }}

  {{- if .containerName }}
    containerName: {{ .containerName }}
  {{- end }}

  {{- if .namespace }}
    namespace: {{ .namespace }}
  {{- else }}
    namespace: {{ $.Release.Namespace }}
  {{- end }}

  {{- if .exclude }}
    exclude: {{ .exclude }}
  {{- end }}

  {{- if .timeout }}
    timeout: {{ .timeout }}
  {{- end }}

  {{- if .args }}
    args:
      {{- range .args }}
      - {{ . }}
      {{- end }}
  {{- end }}

  {{- end }}

{{- end }}
