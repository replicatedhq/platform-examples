{{/*
Renders the Persistent Volume Claim objects required by the chart.
*/}}
{{- define "replicated-library.pvc" -}}
  {{- /* Generate pvc as required */ -}}
  {{- range $name, $values := .Values.persistence -}}
    {{- if $values.enabled  -}}
      {{- if and (eq (default "persistentVolumeClaim" $values.type) "persistentVolumeClaim") (not $values.persistentVolumeClaim.existingClaim) -}}
        {{- $_ := set $.ContextNames "persistence" $name -}}
        {{- $_ := set $.ContextValues "persistence" $values -}}

        {{- include "replicated-library.classes.pvc" $ | nindent 0 -}}

        {{- $_ := unset $.ContextNames "persistence"  -}}
        {{- $_ := unset $.ContextValues "persistence"  -}}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
