{{/*
Expand the name of the chart.
*/}}
{{- define "slackbot.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "slackbot.fullname" -}}
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
{{- define "slackbot.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "slackbot.labels" -}}
helm.sh/chart: {{ include "slackbot.chart" . }}
{{ include "slackbot.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "slackbot.selectorLabels" -}}
app.kubernetes.io/name: {{ include "slackbot.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "slackbot.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "slackbot.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the postgres secret
*/}}
{{- define "slackbot.postgresSecretName" -}}
{{- printf "%s-postgres" (include "slackbot.fullname" .) -}}
{{- end }}

{{/*
Create the name of the slackbot secret
*/}}
{{- define "slackbot.slackSecretName" -}}
{{- printf "%s-slack" (include "slackbot.fullname" .) -}}
{{- end }}

{{/*
Create the postgres hostname
*/}}
{{- define "slackbot.postgresHost" -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end }}
