{{- define "cert-manager.preflight" -}}
apiVersion: troubleshoot.sh/v1beta2
kind: Preflight
metadata:
  name: cert-manager-preflights
spec:
  analyzers:
    # https://github.com/cert-manager/cert-manager/blob/master/deploy/charts/cert-manager/README.template.md#prerequisites
    - clusterVersion:
        outcomes:
          - fail:
              when: "< 1.22.0"
              message: The application requires at least Kubernetes 1.22.0, and recommends 1.25.0.
              uri: https://cert-manager.io/docs/installation/helm/#prerequisites
          - warn:
              when: "< 1.25.0"
              message: Your cluster meets the minimum version of Kubernetes, but we recommend you update to 1.25.0 or later.
              uri: https://cert-manager.io/docs/installation/helm/#prerequisites
          - pass:
              message: Your cluster meets the recommended and required versions of Kubernetes.
{{- end -}} 