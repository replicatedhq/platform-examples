{{/*
This template serves as a blueprint for all Ingress objects that are created
within the replicated-library library.
*/}}
{{- define "replicated-library.classes.ingress" -}}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "ingress") -}}
    {{- $values = .ContextValues.ingress -}}
  {{- else -}}
    {{- fail "_ingress.tpl requires the 'ingress' ContextValues to be set" -}}
  {{- end -}}
  {{- $_ := set $.ContextValues "names" (dict "context" "ingress") -}}

  {{- $isStable := include "replicated-library.capabilities.ingress.isStable" . }}

  {{- $serviceName := $values.serviceName }}
---
apiVersion: {{ include "replicated-library.capabilities.ingress.apiVersion" . }}
kind: Ingress
metadata:
  name: {{ include "replicated-library.names.fullname" . }}
  {{- with (merge ($values.labels | default dict) (include "replicated-library.labels" $ | fromYaml)) }}
  labels: {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (merge ($values.annotations | default dict) (include "replicated-library.annotations" $ | fromYaml)) }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if and $isStable $values.ingressClassName }}
  ingressClassName: {{ $values.ingressClassName }}
  {{- end }}
  {{- if $values.tls }}
  tls:
    {{- range $values.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ tpl . $ | quote }}
        {{- end }}
      {{- if .secretName }}
      secretName: {{ tpl .secretName $ | quote}}
      {{- end }}
    {{- end }}
  {{- end }}
  rules:
  {{- range $values.hosts }}
    - host: {{ tpl .host $ | quote }}
      http:
        paths:
          {{- range .paths }}
          {{- $service := "" -}}
          {{- $port := 80 -}}
          {{- if .service -}}
          {{- if .service.name }}
              {{- $service = .service.name }}
           {{- else if $values.serviceName }}
               {{- $service = $values.serviceName }}
           {{- else }}     
               {{- range $key, $val := $.Values.services }}
                   {{- if and $val.enabled (eq $key $.ContextNames.ingress) }}
                       {{- $service = $.ContextNames.ingress }}
                   {{- end }}
                {{- end }}
            {{- end }}
           {{- range $key, $val := $.Values.services }}
               {{- if and $val.enabled (eq $key $service) -}}
                   {{- $service = printf "%s-%s" (include "replicated-library.names.prefix" $) $service | trunc 63 | trimAll "-"  -}}
               {{- end }}
           {{- end }}
         {{- if not $service -}}
              {{- fail  "a service name is required for the ingress host"  }}
         {{- end }}
            {{- $port = default $port .service.port -}}
          {{- end }}
          - path: {{ tpl .path $ | quote }}
            {{- if $isStable }}
            pathType: {{ default "Prefix" .pathType }}
            {{- end }}
            backend:
              {{- if $isStable }}
              service:
                name: {{ $service }}
                port:
                  number: {{ $port }}
              {{- else }}
              serviceName: {{ $service }}
              servicePort: {{ $port }}
              {{- end }}
          {{- end }}
  {{- end }}
  {{- end }}
