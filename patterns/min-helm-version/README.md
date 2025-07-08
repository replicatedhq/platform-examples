# Define the minimum Helm version for a chart

The [mychart](./mychart/) chart contains a simple pattern that you can use to enforce a minimum version of the Helm client for any chart.

1. Add `annotations.minimumHelmVersion` to your `Chart.yaml`. For example:

    ```yaml
    apiVersion: v2
    name: mychart
    version: 0.1.0
    annotations:
      minimumHelmVersion: 3.18.2
    ```
    _See [mychart/Chart.yaml](./mychart/Chart.yaml)._
1. Add a helper function to your chart's `templates/_helpers.tpl` file, like the `mychart.validateHelmVersion` function below. Replace `mychart` with the name of your chart.

    ```tpl
    {{- define "mychart.validateHelmVersion" -}}
      {{- $minVersion := .Chart.Annotations.minimumHelmVersion }}
      {{- $helmVersion := trimPrefix "v" .Capabilities.HelmVersion.Version }}
      {{- if lt $helmVersion $minVersion }}
        {{- $message := printf "\n\nThis chart requires a minimum version of Helm %s. Please upgrade your Helm version." $minVersion }}
        {{- fail $message }}
      {{- end }}
    {{- end }}
    ```
    _See [mychart/templates/_helpers.tpl](./mychart/templates/_helpers.tpl)._
1. Include your helper function at the top of any template. Make sure this include statement is outside of any rendering conditional logic if you want to always enfore the minimum Helm version.

    ```yaml
    {{- include "mychart.validateHelmVersion" . }}
    apiVersion: v1
    kind: Secret
    metadata:
      name: mysecret
    data:
      foo: YmFyCg==
    ```
    _See [mychart/templates/secret.yaml](./mychart/templates/secret.yaml)._
