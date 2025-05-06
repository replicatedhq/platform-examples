{{/*
Renders the Service objects required by the chart.
*/}}
{{- define "replicated-library.services" -}}
  {{- /* Generate named services as required */ -}}
  {{- range $name, $serviceValues := .Values.services }}
    {{- if $serviceValues.enabled -}}
      {{- $_ := set $.ContextNames "service" $name -}}
      {{- $_ := set $.ContextValues "service" $serviceValues -}}

      {{- include "replicated-library.classes.service" $ | nindent 0 }}

      {{- $_ := unset $.ContextNames "service"  -}}
      {{- $_ := unset $.ContextValues "service"  -}}
    {{- end }}
  {{- end }}
{{- end }}
