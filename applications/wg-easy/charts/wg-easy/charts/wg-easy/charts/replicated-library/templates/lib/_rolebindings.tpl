{{/* Renders RoleBinding objects required by the chart */}}
{{- define "replicated-library.roleBindings" -}}
  {{- range $name, $roleBindingValues := .Values.roleBindings -}}
    {{- if $roleBindingValues.enabled  -}}
      {{- $_ := set $.ContextNames "roleBinding" $name -}}
      {{- $_ := set $.ContextValues "roleBinding" $roleBindingValues -}}
      {{- include "replicated-library.roleBinding" $ | nindent 0 }}
      {{- $_ := unset $.ContextNames "roleBinding" -}}
      {{- $_ := unset $.ContextValues "roleBinding" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
