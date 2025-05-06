{{/* Expand the name of the chart */}}
{{- define "replicated-library.names.name" -}}
  {{- $globalNameOverride := "" -}}
  {{- if hasKey .Values "global" -}}
    {{- $globalNameOverride = (default $globalNameOverride .Values.global.nameOverride) -}}
  {{- end -}}
  {{- default .Chart.Name (default "" $globalNameOverride) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* 
Return the object prefix including user provided overrides. 
Prefix will be of the form: ReleaseName-ChartName.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
The global nameOverride will replace the ChartName if provided.
The global fullNameOverride will replace the entire prefix if provided.
The ChartName will not be included if it is contained in the ReleaseName, leaving only the ReleaseName.
*/}}
{{- define "replicated-library.names.prefix" -}}
  {{- if and (hasKey .Values "global") ( and (hasKey .Values.global "fullNameOverride") .Values.global.fullNameOverride) -}}
    {{- trunc 63 .Values.global.fullNameOverride | trimSuffix "-" -}}
  {{- else -}}
    {{- $chartName := include "replicated-library.names.name" . -}}
    {{- if contains $chartName .Release.Name -}}
      {{- trunc 63 .Release.Name | trimSuffix "-" -}}
    {{- else -}}
      {{- printf "%s-%s" .Release.Name $chartName | trunc 63 | trimSuffix "-" -}}
    {{- end -}}
  {{- end -}}
{{- end }}

{{/*
Create a default fully qualified object name.
This function will fail if called outside the scope of an object.
If only the prefix is needed use "replicated-library.names.prefix" instead.
If fullNameOverride is provided on the object it will take precedence over the normal prefix calculation.
*/}}
{{- define "replicated-library.names.fullname" -}}
  {{- $objectName := "" -}}
  {{- $values := . -}}
  {{- if and (hasKey .ContextValues "names") (hasKey .ContextValues.names "context") -}}
    {{- $contextKey := .ContextValues.names.context -}}
    {{- $objectName = get .ContextNames $contextKey -}}
    {{- $values = get .ContextValues $contextKey -}}
  {{- end -}}

  {{- if $values.fullNameOverride -}}
    {{- trunc 63 $values.fullNameOverride | trimSuffix "-" -}}
  {{- else -}}
    {{- $prefix := include "replicated-library.names.prefix" . -}}
    {{- printf "%s-%s" $prefix $objectName | trunc 63 | trimAll "-" -}}
  {{- end -}}
{{- end -}}

{{/* Create chart name and version as used by the chart label */}}
{{- define "replicated-library.names.chart" -}}
  {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Create the name of the ServiceAccount to use */}}
{{- define "replicated-library.names.serviceAccountName" -}}
  {{- $values := . -}}
  {{- if and (hasKey .ContextValues "names") (hasKey .ContextValues.names "context") -}}
    {{- $values = get .ContextValues .ContextValues.names.context -}}
  {{- end -}}

  {{- if $values.serviceAccount -}}
    {{- if $values.serviceAccount.create -}}
      {{- default (include "replicated-library.names.fullname" .) $values.serviceAccount.name -}}
    {{- else -}}
      {{- default "default" $values.serviceAccount.name -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/* Get name of current app */}}
{{- define "replicated-library.names.appname" -}}
  {{- $objectName := "" -}}
  {{- if and (hasKey .ContextValues "names") (hasKey .ContextValues.names "context") -}}
    {{- $contextKey := .ContextValues.names.context -}}
    {{- $objectName = get .ContextNames .ContextValues.names.context -}}
  {{- end -}}
  {{- trunc 63 $objectName | trimSuffix "-" -}}
{{- end -}}

{{/* Get name of current service */}}
{{- define "replicated-library.names.servicename" -}}
  {{- $objectName := "" -}}
  {{- if and (hasKey .ContextValues "names") (hasKey .ContextValues.names "context") -}}
    {{- $contextKey := .ContextValues.names.context -}}
    {{- $objectName = get .ContextNames .ContextValues.names.context -}}
  {{- else -}}
    {{- fail (print "not found .ContextValues.names.context") }}
  {{ end -}}
  {{- trunc 63 $objectName | trimSuffix "-" -}}
{{- end -}}
