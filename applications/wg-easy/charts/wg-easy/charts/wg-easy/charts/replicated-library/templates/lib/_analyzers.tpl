{{/*
Renders the Support Bundle Analyzers objects required by the chart.
*/}}
{{- define "replicated-library.troubleshoot.analyzers" -}}
  {{- range $analyzer := .ContextValues.troubleshoot.analyzers -}}
    {{- range $name, $analyzerValues := $analyzer -}}
      {{- $_ := set $.ContextNames "analyzer" $name -}}
      {{- $_ := set $.ContextValues "analyzer" $analyzerValues -}}

      {{- include "replicated-library.troubleshoot.analyzer" $ | nindent 2 }}

      {{- $_ := unset $.ContextNames "analyzer"  -}}
      {{- $_ := unset $.ContextValues "analyzer"  -}}
    {{- end -}}
  {{- end -}}
{{- end }}
