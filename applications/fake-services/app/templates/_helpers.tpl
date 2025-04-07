{{/*
Expand the name of the chart.
*/}}
{{- define "fake-service.name" -}}
{{- default .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fake-service.fullname" -}}
{{- $name := "fake-service-app" }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "fake-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fake-service.labels" -}}
helm.sh/chart: {{ include "fake-service.chart" . }}
{{ include "fake-service.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "fake-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fake-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Frontend labels selector
*/}}
{{- define "fake-service.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fake-service.name" . }}-frontend
{{- end }}

{{/*
Backend labels selector
*/}}
{{- define "fake-service.backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fake-service.name" . }}-backend
{{- end }}

{{/*
Frontend service name
*/}}
{{- define "fake-service.frontend.name" -}}
frontend-service
{{- end }}

{{/*
Backend service name
*/}}
{{- define "fake-service.backend.name" -}}
backend-service
{{- end }}

{{/*
Rqlite UI service name
*/}}
{{- define "fake-service.rqliteui.name" -}}
rqlite-ui-service
{{- end }}

{{/*
Rqlite UI labels selector
*/}}
{{- define "fake-service.rqliteui.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fake-service.name" . }}-rqliteui
{{- end }}

{{/*
Minio UI labels selector
*/}}
{{- define "fake-service.minioui.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fake-service.name" . }}-minioui
{{- end }}

{{/*
Image Pull Secrets
*/}}
{{- define "helpers.imagePullSecrets" -}}
{{- $pullSecrets := list -}}

{{/* Add existing imagePullSecrets if defined */}}
{{- if .Values.image.imagePullSecrets -}}
{{- $pullSecrets = concat $pullSecrets .Values.image.imagePullSecrets -}}
{{- end -}}

{{/* Add replicated pull secret if global dockerconfigjson is defined */}}
{{- if hasKey .Values "global" -}}
{{- if hasKey .Values.global "replicated" -}}
{{- if .Values.global.replicated.dockerconfigjson -}}
{{- $replicatedSecret := dict "name" "replicated-pull-secret" -}}
{{- $pullSecrets = append $pullSecrets $replicatedSecret -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Output the imagePullSecrets block only if we have any secrets */}}
{{- if $pullSecrets -}}
imagePullSecrets:
{{- range $pullSecrets }}
  - name: {{ .name }}
{{- end -}}
{{- end -}}
{{- end -}}