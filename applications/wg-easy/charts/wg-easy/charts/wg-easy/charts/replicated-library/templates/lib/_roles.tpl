{{/* Renders the Role objects required by the chart */}}
{{- define "replicated-library.roles" -}}
  {{- range $name, $roleValues := .Values.roles -}}
    {{- if $roleValues.enabled -}}
      {{- $_ := set $.ContextNames "role" $name -}}
      {{- $_ := set $.ContextValues "role" $roleValues -}}

      {{- include "replicated-library.role" $ | nindent 0 }}
      {{- $_ := unset $.ContextNames "role" -}}
      {{- $_ := unset $.ContextValues "role" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
