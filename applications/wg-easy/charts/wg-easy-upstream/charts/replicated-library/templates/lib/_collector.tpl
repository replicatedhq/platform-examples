{{/*
Renders the Support Bundle Collectors objects required by the chart.
*/}}
{{- define "replicated-library.troubleshoot.collector" -}}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "collector") -}}
    {{- $values = .ContextValues.collector -}}
  {{- else -}}
    {{- fail "_collector.tpl requires the 'collector' ContextValues to be set" -}}
  {{- end -}}
  {{- $_ := set $.ContextValues "names" (dict "context" "collector") -}}
    
  {{- if eq .ContextNames.collector "logs" -}}
    {{ include "replicated-library.troubleshoot.collector.logs" $ }}
  {{- else if eq .ContextNames.collector "exec" -}}
    {{ include "replicated-library.troubleshoot.collector.exec" $ }}
  {{- else if eq .ContextNames.collector "secret" -}}
    {{ include "replicated-library.troubleshoot.collector.secret" $ }}
  {{- else if eq .ContextNames.collector "data" -}}
    {{ include "replicated-library.troubleshoot.collector.data" $ }}
  {{- else if eq .ContextNames.collector "imagePullSecret" -}}
    {{ include "replicated-library.troubleshoot.collector.imagePullSecret" $ }}
  {{- else if eq .ContextNames.collector "configMap" -}}
    {{ include "replicated-library.troubleshoot.collector.configMap" $ }}
  {{- else if eq .ContextNames.collector "collectd" -}}
    {{ include "replicated-library.troubleshoot.collector.collectd" $ }}
  {{- else -}}
    {{ include "replicated-library.troubleshoot.collector.general" $ }}
  {{- end }}

{{- end }}
