{{/*
Garage fullname (scoped to parent release)
*/}}
{{- define "garage.fullname" -}}
{{ .Release.Name }}-garage
{{- end -}}

{{/*
Garage labels
*/}}
{{- define "garage.labels" -}}
app.kubernetes.io/name: garage
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: object-storage
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Garage selector labels
*/}}
{{- define "garage.selectorLabels" -}}
app.kubernetes.io/name: garage
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: object-storage
{{- end -}}
