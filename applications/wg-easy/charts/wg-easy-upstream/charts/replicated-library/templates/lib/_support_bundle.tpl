{{/*
Renders the Support Bundle objects required by the chart.
*/}}
{{- define "replicated-library.supportBundle" -}}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "troubleshoot") -}}
    {{- $values = .ContextValues.troubleshoot -}}
  {{- else -}}
    {{- fail "_support_bundle.tpl requires the 'troubleshoot' ContextValues to be set" -}}
  {{- end -}}
---
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "replicated-library.names.prefix" . }}-support-bundle-{{ .ContextNames.troubleshoot }}
  labels:
    troubleshoot.sh/kind: support-bundle
stringData:
  support-bundle-spec: |-
    apiVersion: troubleshoot.sh/v1beta2
    kind: SupportBundle
    metadata:
      name: {{ include "replicated-library.names.prefix" . }}-support-bundle-{{ .ContextNames.troubleshoot }}
    spec:
      {{- if $values.uri }}
      uri: {{ $values.uri }}
      {{- end }}
      {{- if $values.collectors }}
      collectors:
        {{- include "replicated-library.troubleshoot.collectors" . | indent 6 }}
      {{- end }}
      {{- if $values.analyzers }}
      analyzers:
       {{- include "replicated-library.troubleshoot.analyzers" . | indent 6 }}
      {{- end }}
{{- end }}
