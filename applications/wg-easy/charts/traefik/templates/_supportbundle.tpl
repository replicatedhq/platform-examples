{{- define "traefik.supportbundle" -}}
apiVersion: troubleshoot.sh/v1beta2
kind: SupportBundle
metadata:
  name: traefik-supportbundle
spec:
  collectors:
    - logs:
        namespace: {{ .Release.Namespace }}
        selector:
        - app.kubernetes.io/name=traefik
{{- end -}} 
