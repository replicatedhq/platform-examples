{{/*
Renders the Support Bundle objects required by the chart.
*/}}
{{- define "replicated-library.preflights" -}}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "troubleshoot") -}}
    {{- $values = .ContextValues.troubleshoot -}}
  {{- else -}}
    {{- fail "_preflights.tpl requires the 'troubleshoot' ContextValues to be set" -}}
  {{- end -}}
---
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "replicated-library.names.prefix" . }}-preflight-{{ .ContextNames.troubleshoot }}
  labels:
    {{- include "replicated-library.labels" $ | nindent 4 }}
    troubleshoot.sh/kind: preflight
  annotations:
    "helm.sh/hook": pre-install, pre-upgrade
    "helm.sh/hook-weight": "-6"
    "helm.sh/hook-delete-policy": before-hook-creation, hook-succeeded, hook-failed
stringData:
  preflight.yaml: |-
    apiVersion: troubleshoot.sh/v1beta2
    kind: Preflight
    metadata:
      name: {{ include "replicated-library.names.prefix" . }}-preflight-{{ .ContextNames.troubleshoot }}
    spec:
      {{- if $values.collectors }}
      collectors:
        {{- include "replicated-library.troubleshoot.collectors" . | indent 6 }}
      {{- end }}
      {{- if $values.analyzers }}
      analyzers:
       {{- include "replicated-library.troubleshoot.analyzers" . | indent 6 }}
      {{- else -}}
        {{- fail (printf "Preflight %s requires the analyzers to be set" .ContextNames.troubleshoot) }}
      {{- end }}

{{ if $values.enableRBAC -}}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ $.Release.Name }}-preflight-{{ .ContextNames.troubleshoot }}
  labels:
    {{- include "replicated-library.labels" $ | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install, pre-upgrade
    "helm.sh/hook-weight": "-6"
    "helm.sh/hook-delete-policy": before-hook-creation, hook-succeeded, hook-failed
secrets:
  - name: {{ include "replicated-library.names.prefix" . }}-preflight-{{ .ContextNames.troubleshoot }}

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ $.Release.Name }}-preflight-{{ .ContextNames.troubleshoot }}
  labels:
    {{- include "replicated-library.labels" $ | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install, pre-upgrade
    "helm.sh/hook-weight": "-6"
    "helm.sh/hook-delete-policy": before-hook-creation, hook-succeeded, hook-failed
rules:
  - apiGroups:
      - ""
    resources: 
      - "namespaces"
    verbs: 
      - "get"
      - "watch"
      - "list"
  - apiGroups:
      - ""
    resources: 
      - "nodes"
    verbs: 
      - "get"
      - "watch"
      - "list"
  - apiGroups:
      - ""
    resources: 
      - "pods"
    verbs: 
      - "get"
      - "watch"
      - "list"
      - "create"
  - apiGroups: 
      - "apiextensions.k8s.io"
    resources: 
      - "customresourcedefinitions"
    verbs: 
      - "get"
      - "watch"
      - "list"
  - apiGroups: 
      - "storage.k8s.io"
    resources: 
      - "storageclasses"
    verbs: 
      - "get"
      - "watch"
      - "list"
  - apiGroups:
      - ""
    resources: 
      - "pods/log"
    verbs: 
      - "get"
      - "list"

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ $.Release.Name }}-preflight-{{ .ContextNames.troubleshoot }}
  labels:
    {{- include "replicated-library.labels" $ | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install, pre-upgrade
    "helm.sh/hook-weight": "-6"
    "helm.sh/hook-delete-policy": before-hook-creation, hook-succeeded, hook-failed
subjects:
- kind: ServiceAccount
  name: {{ $.Release.Name }}-preflight-{{ .ContextNames.troubleshoot }}
  namespace: {{ $.Release.Namespace }}
roleRef:
  kind: ClusterRole 
  name: {{ $.Release.Name }}-preflight-{{ .ContextNames.troubleshoot }}
  apiGroup: rbac.authorization.k8s.io

{{- end -}}
---
apiVersion: v1
kind: Pod
metadata:
  name: {{ $.Release.Name }}-preflight-check
  labels:
    {{- include "replicated-library.labels" $ | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install, pre-upgrade
    "helm.sh/show-output": "true"
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation, hook-succeeded, hook-failed
    "helm.sh/hook-output-log-policy": hook-failed, hook-succeeded
spec:
{{- if $values.enableRBAC }}
  serviceAccountName: {{ $.Release.Name }}-preflight-{{ .ContextNames.troubleshoot }}
{{- end }}
  restartPolicy: Never
  volumes:
    - name: preflights
      secret:
        secretName: {{ include "replicated-library.names.prefix" . }}-preflight-{{ .ContextNames.troubleshoot }}
  containers:
    - name: pre-install-job
      image:  {{ default "replicated/preflight:latest" $values.image }}
      command:
        - "preflight"
        - "--interactive=false"
        - "/preflights/preflight.yaml"
      volumeMounts:
        - name: preflights
          mountPath: /preflights

{{- end }}
