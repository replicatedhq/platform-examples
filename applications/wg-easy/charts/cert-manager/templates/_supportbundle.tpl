{{- define "cert-manager.supportbundle" -}}
apiVersion: troubleshoot.sh/v1beta2
kind: SupportBundle
metadata:
  name: cert-manager-supportbundle
spec:
  collectors:
    - logs:
        namespaces: {{ .Release.Namespace }}
        selector:
        - app.kubernetes.io/instance=cert-manager
{{- end -}}
