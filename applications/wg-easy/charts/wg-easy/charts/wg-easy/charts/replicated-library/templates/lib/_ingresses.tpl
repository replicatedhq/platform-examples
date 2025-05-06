{{/*
Renders the Service objects required by the chart.
*/}}
{{- define "replicated-library.ingresses" -}}
  {{- /* Generate named ingresses as required */ -}}
  {{- range $name, $ingressValues := .Values.ingresses }}
    {{- if $ingressValues.enabled -}}
      {{- $_ := set $.ContextNames "ingress" $name -}}
      {{- $_ := set $.ContextValues "ingress" $ingressValues -}}

      {{- if $ingressValues.serviceName }}
        {{- $matchingAppFound := false -}}

        {{- range $serviceName, $serviceValues := $.Values.services }}
          {{- if and $serviceValues.enabled (eq $serviceName $ingressValues.serviceName) (ne $matchingAppFound true) -}}
            {{- $matchingAppFound = true -}}
            {{- include "replicated-library.classes.ingress" $ | nindent 0 }}
          {{- end }}
        {{- end }}

        {{- if (ne $matchingAppFound true) -}}
          {{- fail (printf "Matching service for ServiceName (%s) was not found" $ingressValues.serviceName) }}
        {{- end }}

      {{- else }}
        {{- include "replicated-library.classes.ingress" $ | nindent 0 }}
      {{- end }}

      {{- $_ := unset $.ContextNames "ingress"  -}}
      {{- $_ := unset $.ContextValues "ingress"  -}}

    {{- end }}
  {{- end }}
{{- end }}
