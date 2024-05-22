# Self-signed Ingress TLS Certificate vs. User-provided

If you are providing a TLS secret with your app to terminate TLS with Kubernetes Ingress, you will likely want the ability to let users decide between providing their own certificate vs. defaulting to a self-signed one.

Source Application: [Mlflow](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow)

1. Add the tls configuration to your helm chart values

[Mlflow Helm Values](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/chart/mlflow/values.yaml)
```yaml
ingress:
  enabled: true
  hostname: chart-example.local
  tls:
    enabled: true
    genSelfSignedCert: true
    cert: |
      -----BEGIN CERTIFICATE-----
      -----END CERTIFICATE-----
    key: |
      -----BEGIN PRIVATE KEY-----
      -----END PRIVATE KEY-----
```

2. Add a tls secret to your chart and implement the templating to conditionally choose between user-provided and self-signed

[Mlflow TLS Secret](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/chart/mlflow/templates/tls.yaml)
```yaml
{{- if .Values.mlflow.ingress.tls.enabled -}}
  {{- $cert := dict -}}
  {{- if .Values.mlflow.ingress.tls.genSelfSignedCert -}}
    {{ $cert = genSelfSignedCert .Values.mlflow.ingress.hostname nil nil 730 }}
  {{- else -}}
    {{- $_ := set $cert "Cert" .Values.mlflow.ingress.tls.cert -}}
    {{- $_ := set $cert "Key" .Values.mlflow.ingress.tls.key -}}
  {{- end -}}
apiVersion: v1
data:
  tls.crt: {{ $cert.Cert | b64enc }}
  tls.key: {{ $cert.Key | b64enc }}
kind: Secret
metadata:
  name: {{ include "mlflow.fullname" . }}-tls
type: kubernetes.io/tls
{{- end -}}
```

3. In KOTS you can expose config options to allow a user to optionally upload a cert if the "User Provided" TLS option is selected

[Mlflow KOTS Config](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/kots/manifests/kots-config.yaml)
```yaml
apiVersion: kots.io/v1beta1
kind: Config
metadata:
  name: config
spec:
  groups:
  # Ingress settings
  - name: ingress_settings
    title: Ingress Settings
    description: Configure Ingress for Mlflow
    items:
    - name: mlflow_ingress_tls_type
      title: Mlflow Ingress TLS Type
      type: select_one
      items:
      - name: self_signed
        title: Self Signed (Generate Self Signed Certificate)
      - name: user_provided
        title: User Provided (Upload a TLS Certificate and Key Pair)
      required: true
      default: self_signed
      when: 'repl{{ ConfigOptionEquals "mlflow_ingress_type" "ingress_controller" }}'
    - name: mlflow_ingress_tls_cert
      title: Mlflow TLS Cert
      type: file
      when: '{{repl and (ConfigOptionEquals "mlflow_ingress_type" "ingress_controller") (ConfigOptionEquals "mlflow_ingress_tls_type" "user_provided") }}'
      required: true
    - name: mlflow_ingress_tls_key
      title: Mlflow TLS Key
      type: file
      when: '{{repl and (ConfigOptionEquals "mlflow_ingress_type" "ingress_controller") (ConfigOptionEquals "mlflow_ingress_tls_type" "user_provided") }}'
      required: true
```

[Mlflow KOTS Helm Chart](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/kots/manifests/helm-mlflow.yaml)
```yaml
apiVersion: kots.io/v1beta2
kind: HelmChart
metadata:
  name: mlflow
spec:
  chart:
    name: mlflow
    chartVersion: 0.1.2
  weight: 1
  values:
    mlflow:
      ingress:
        enabled: true
        hostname: repl{{ ConfigOption "mlflow_ingress_host"}}
        tls:
          enabled: true
          genSelfSignedCert: repl{{ ConfigOptionEquals "mlflow_ingress_tls_type" "self_signed" }}
          cert: repl{{ print `|`}}repl{{ ConfigOptionData `mlflow_ingress_tls_cert` | nindent 12 }}
          key: repl{{ print `|`}}repl{{ ConfigOptionData `mlflow_ingress_tls_key` | nindent 12 }}
```
