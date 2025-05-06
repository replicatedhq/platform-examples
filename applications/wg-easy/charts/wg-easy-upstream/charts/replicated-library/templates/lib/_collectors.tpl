{{/*
Renders the Support Bundle Collectors objects required by the chart.
*/}}
{{- define "replicated-library.troubleshoot.collectors" -}}
  {{- range $collector := .ContextValues.troubleshoot.collectors -}}
    {{- range $name, $collectorValues := $collector -}}
      {{- $_ := set $.ContextNames "collector" $name -}}
      {{- $_ := set $.ContextValues "collector" $collectorValues -}}

      {{- include "replicated-library.troubleshoot.collector" $ | nindent 2 }}
      
      {{- $_ := unset $.ContextNames "collector"  -}}
      {{- $_ := unset $.ContextValues "collector"  -}}
    {{- end -}}
  {{- end -}}
{{- end }}
