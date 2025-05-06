{{/* Merge the local chart values and the replicated-library chart defaults */}}
{{- define "replicated-library.values.setup" -}}
  {{- if (index .Values "replicated-library") -}}
    {{- $defaultValues := deepCopy (index .Values "replicated-library") -}}
    {{- $userValues := deepCopy (omit .Values "replicated-library") -}}
    {{- $mergedValues := mustMergeOverwrite $defaultValues $userValues -}}
    {{- $_ := set . "Values" (deepCopy $mergedValues) -}}
  {{- end -}}
{{- end -}}
