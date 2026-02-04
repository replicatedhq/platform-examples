{{/*
Expand the name of the chart.
*/}}
{{- define "flipt.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "flipt.fullname" -}}
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
{{- define "flipt.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "flipt.labels" -}}
helm.sh/chart: {{ include "flipt.chart" . }}
{{ include "flipt.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "flipt.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flipt.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
PostgreSQL connection URL
*/}}
{{- define "flipt.postgresql.url" -}}
{{- if eq .Values.postgresql.type "embedded" }}
{{- printf "postgres://%s:%s@%s-cluster-rw.%s.svc.cluster.local:5432/%s?sslmode=require" .Values.postgresql.username .Values.postgresql.password .Release.Name .Release.Namespace .Values.postgresql.database }}
{{- else }}
{{- printf "postgres://%s:%s@%s:%d/%s?sslmode=%s" .Values.postgresql.external.username .Values.postgresql.external.password .Values.postgresql.external.host (int .Values.postgresql.external.port) .Values.postgresql.external.database .Values.postgresql.external.sslMode }}
{{- end }}
{{- end }}

{{/*
Redis connection URL
*/}}
{{- define "flipt.redis.url" -}}
{{- if .Values.redis.enabled }}
{{- if .Values.redis.auth.enabled }}
{{- printf "redis://:%s@%s-redis-master.%s.svc.cluster.local:6379" .Values.redis.auth.password .Release.Name .Release.Namespace }}
{{- else }}
{{- printf "redis://%s-redis-master.%s.svc.cluster.local:6379" .Release.Name .Release.Namespace }}
{{- end }}
{{- else }}
{{- "" }}
{{- end }}
{{- end }}

{{/*
PostgreSQL cluster name for CloudnativePG
*/}}
{{- define "flipt.postgresql.clustername" -}}
{{- printf "%s-cluster" .Release.Name }}
{{- end }}

{{/*
Database secret name
*/}}
{{- define "flipt.postgresql.secret" -}}
{{- if eq .Values.postgresql.type "embedded" }}
{{- printf "%s-cluster-app" .Release.Name }}
{{- else }}
{{- printf "%s-postgresql-external" (include "flipt.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Redis secret name
*/}}
{{- define "flipt.redis.secret" -}}
{{- printf "%s-redis" .Release.Name }}
{{- end }}
