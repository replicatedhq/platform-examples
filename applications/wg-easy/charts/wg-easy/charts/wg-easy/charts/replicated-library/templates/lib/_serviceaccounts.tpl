{{/* Renders the ServiceAccount objects required by the chart */}}
{{- define "replicated-library.serviceAccounts" -}}
{{- range $name, $serviceAccountValues := .Values.serviceAccounts -}}
    {{- if $serviceAccountValues.enabled -}}
      {{- $_ := set $.ContextNames "serviceAccount" $name -}}
      {{- $_ := set $.ContextValues "serviceAccount" $serviceAccountValues -}}

      {{- include "replicated-library.serviceAccount" $ | nindent 0 }}
      {{- $_ := unset $.ContextNames "serviceAccount" -}}
      {{- $_ := unset $.ContextValues "serviceAccount" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
