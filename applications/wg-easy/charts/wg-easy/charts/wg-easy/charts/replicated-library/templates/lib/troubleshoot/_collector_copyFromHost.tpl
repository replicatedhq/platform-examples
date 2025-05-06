{{- define "replicated-library.troubleshoot.collector.copyFromHost" -}}
- {{ .ContextNames.collector }}:
  {{- with .ContextValues.collector }}
    {{- if .hostPath }}
    hostPath: {{ .hostPath }}
    {{- else }}
      {{- fail (printf "The 'hostPath' for the 'copyFromHost' collector was not found." ) }}
    {{- end }}

    {{- if .image }}
    image: {{ .image }}
    {{- else }}
      {{- fail (printf "The 'image' for the 'copyFromHost' collector was not found." ) }}
    {{- end }}

    {{- if .name }}
    name: {{ .name }}
    {{- end }}

    {{- if .collectorName }}
    collectorName: {{ .collectorName }}
    {{- end }}

    {{- if .timeout }}
    timeout: {{ .timeout }}
    {{- end }}

    {{- if .namespace }}
    namespace: {{ .namespace }}
    {{- end }}

    {{- if .extractArchive }}
    extractArchive: {{ .extractArchive }}
    {{- end }}

    {{- if .imagePullPolicy }}
    imagePullPolicy: {{ .imagePullPolicy }}
    {{- end }}

    {{- if .imagePullSecret }}
    imagePullSecret: {{ .imagePullSecret }}
    {{- end }}
  {{- end }}
{{- end }}
