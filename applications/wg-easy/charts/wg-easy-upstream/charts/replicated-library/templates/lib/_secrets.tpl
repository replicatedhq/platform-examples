{{/*
Renders the Secret objects required by the chart.
*/}}
{{- define "replicated-library.secrets" -}}
  {{- /* Generate named secrets as required */ -}}
  {{- range $name, $secretValues := .Values.secrets }}
    {{- if $secretValues.enabled -}}
      {{- $_ := set $.ContextNames "secret" $name -}}
      {{- $_ := set $.ContextValues "secret" $secretValues -}}

      {{- include "replicated-library.classes.secret" $ | nindent 0 }}

      {{- $_ := unset $.ContextNames "secret"  -}}
      {{- $_ := unset $.ContextValues "secret"  -}}
    {{- end }}
  {{- end }}
{{- end }}
