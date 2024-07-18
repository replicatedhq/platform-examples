{{/*
The name of the chart.
*/}}
{{- define "crdCheck.fullname" -}}
{{- printf "%s-%s" .Release.Name "crd-check" | trunc 63 | trimSuffix "-" }}
{{- end }}
