# Support bundles in helm charts

A quick note on structure and formatting for support bundles in helm charts

## structure

Each helm chart in your release should contain a support bundle spec that collects and analyzes resources that are installed by that chart.

If you're installing a helm chart from an upstream project that doesn't supply their own support bundles, you can include it as a sub-chart of a wrapper inside your release:

```
  app-workspace
  ├─ cert-manager-HelmChart.yaml
  ├─ cert-manager
  ┊  ├─ Chart.yaml
     └─ templates
        ├─ _supportbundle.tpl
        ├─ secret-supportbundle.yaml
        ┊
```

`cert-manager-HelmChart.yaml`
```yaml
apiVersion: kots.io/v1beta2
kind: HelmChart
metadata:
  name: cert-manager
spec:
  chart:
    name: cert-manager
```

`Chart.yaml`
```yaml
name: cert-manager
apiVersion: v2
version: 1.0.0
dependencies:
  - name: cert-manager
    version: '1.14.5'
    repository: https://charts.jetstack.io
```

You can see examples of this wrapper chart structure:
- [Wrapped cert-manager chart](https://github.com/replicatedhq/platform-examples/tree/main/applications/wg-easy/charts/cert-manager)
- [Wrapped traefik chart](https://github.com/replicatedhq/platform-examples/tree/main/applications/wg-easy/charts/traefik)

## formatting

To ease writing support bundles inside a secret, we can use a simple template `include` pattern to avoid having to write nested yaml structures.

`templates/secret-supportbundle.yaml`
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cert-manager-supportbundle
  labels:
    troubleshoot.sh/kind: support-bundle
type: Opaque
stringData:
  support-bundle-spec: |
{{ include "cert-manager.supportbundle" . | indent 4 }} 
```

`templates/_supportbundle.tpl`
```yaml
{{- define "cert-manager.supportbundle" -}}
apiVersion: troubleshoot.sh/v1beta2
kind: SupportBundle
metadata:
  name: cert-manager-supportbundle
spec:
  collectors:
    - logs:
        namespace: {{ .Release.Namespace }}
        selector:
        - app.kubernetes.io/instance=cert-manager
{{- end -}} 
```

Some further examples can be found:
- [Traefik support bundles and preflights](https://github.com/replicatedhq/platform-examples/tree/main/applications/wg-easy/charts/traefik/templates)
- [cert-manager support bundles and preflights](https://github.com/replicatedhq/platform-examples/tree/main/applications/wg-easy/charts/cert-manager/templates)
