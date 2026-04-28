{{/*
Expand the name of the chart.
*/}}
{{- define "license-validation.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "license-validation.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "license-validation.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "license-validation.labels" -}}
helm.sh/chart: {{ include "license-validation.chart" . }}
{{ include "license-validation.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "license-validation.selectorLabels" -}}
app.kubernetes.io/name: {{ include "license-validation.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Replicated SDK address - auto-detect from release name if not explicitly set.
*/}}
{{- define "license-validation.sdkAddress" -}}
{{- if .Values.replicatedSDKAddress }}
{{- .Values.replicatedSDKAddress }}
{{- else }}
{{- printf "http://%s-replicated:3000" .Release.Name }}
{{- end }}
{{- end }}
