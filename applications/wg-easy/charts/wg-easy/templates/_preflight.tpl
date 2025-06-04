{{- define "wg-easy.preflight" -}}
apiVersion: troubleshoot.sh/v1beta2
kind: Preflight
metadata:
  name: wg-easy-preflights
spec:
  collectors:
    - sysctl:
        image: {{ .Values.preflight.image.repository }}
  analyzers:
    - sysctl:
        checkName: IP forwarding enabled
        outcomes:
          - fail:
              when: 'net.ipv4.ip_forward == 0'
              message: "IP forwarding must be enabled. To enable it, edit /etc/sysctl.conf, add or uncomment the line 'net.ipv4.ip_forward=1', and run 'sudo sysctl -p'."
          - pass:
              when: 'net.ipv4.ip_forward == 1'
              message: "IP forwarding is enabled."
{{- end -}} 