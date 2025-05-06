{{/*
Renders the app objects into Deployments, DaemonSets, and StatefulSets as required by the chart.
*/}}
{{- define "replicated-library.apps" -}}
  {{- range $name, $appValues := .Values.apps }}
    {{- if $appValues.enabled -}}
      {{- $_ := set $.ContextNames "app" $name -}}
      {{- $_ := set $.ContextValues "app" $appValues -}}
      {{- $_ := set $.ContextValues "names" (dict "context" "app") -}}

      {{- if eq $appValues.type "deployment" }}
        {{- include "replicated-library.deployment" $ | nindent 0 }}
      {{ else if eq $appValues.type "daemonset" }}
        {{- include "replicated-library.daemonset" $ | nindent 0 }}
      {{ else if eq $appValues.type "statefulset"  }}
        {{- include "replicated-library.statefulset" $ | nindent 0 }}
      {{ else }}
        {{- fail (printf "Type of (%s) for app - (%s) is not valid" $appValues.type $name) }}
      {{ end -}}

      {{- $_ := unset $.ContextNames "app"  -}}
      {{- $_ := unset $.ContextValues "app"  -}}
      {{- $_ := unset $.ContextValues "names"  -}}
    {{- end }}
  {{- end }}
{{- end }}
