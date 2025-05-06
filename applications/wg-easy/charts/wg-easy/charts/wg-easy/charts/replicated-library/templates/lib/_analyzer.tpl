{{/*
Renders the Support Bundle Analyzers objects required by the chart.
*/}}
{{- define "replicated-library.troubleshoot.analyzer" -}}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "analyzer") -}}
    {{- $values = .ContextValues.analyzer -}}
  {{- else -}}
    {{- fail "_analyzer.tpl requires the 'analyzer' ContextValues to be set" -}}
  {{- end -}}
  {{- $_ := set $.ContextValues "names" (dict "context" "analyzer") -}}


  {{ include "replicated-library.troubleshoot.analyzer.general" $ }}


{{- end }}