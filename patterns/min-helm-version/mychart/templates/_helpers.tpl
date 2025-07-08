{{- define "mychart.validateHelmVersion" -}}
  {{- $minVersion := .Chart.Annotations.minimumHelmVersion }}
  {{- $helmVersion := trimPrefix "v" .Capabilities.HelmVersion.Version }}
  {{- if lt $helmVersion $minVersion }}
    {{- $message := printf "\n\nThis chart requires a minimum version of Helm %s. Please upgrade your Helm version." $minVersion }}
    {{- fail $message }}
  {{- end }}
{{- end }}
