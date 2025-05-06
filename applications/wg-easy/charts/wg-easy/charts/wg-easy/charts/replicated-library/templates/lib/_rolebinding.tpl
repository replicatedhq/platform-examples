{{/*
This template serves as the blueprint for a RoleBinding object created within the replicated-library library.

TODO: implement support for subjects other than ServiceAccounts
*/}}
{{- define "replicated-library.roleBinding" }}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "roleBinding") -}}
    {{- $values = .ContextValues.roleBinding -}}
  {{- else -}}
    {{- fail "_rolebinding.tpl requires the 'roleBinding' ContextValues to be set" -}}
  {{- end -}}
  {{- $_ := set $.ContextValues "names" (dict "context" "roleBinding") -}}
---
apiVersion: rbac.authorization.k8s.io/v1
{{- $kind := default "RoleBinding" $values.kind -}}
{{- $roleKind := default "Role" $values.roleRef.kind -}}
{{- if and (eq $kind "ClusterRoleBinding") (ne $roleKind "ClusterRole") -}}
  {{- fail (printf "Not a valid Role in roleRef (%s); if a ClusterRoleBinding is created, roleRef must be a ClusterRole" $kind) -}}
{{- end }}
kind: {{ $kind }}
metadata:
  name: {{ include "replicated-library.names.fullname" . }}
  {{- with (merge ($values.labels | default dict) (include "replicated-library.labels" $ | fromYaml)) }}
  labels: {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (merge ($values.annotations | default dict) (include "replicated-library.annotations" $ | fromYaml)) }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
subjects:
  {{- range $s := $values.subjects }}
  - apiGroup: ""
    {{- $subjectKind := default "ServiceAcount" $s.kind }}
    {{- if ne $subjectKind "ServiceAccount" }}
      {{- fail (printf "Currently, only ServiceAccounts are supported as subjects in RoleBindings. Found: %s" $subjectKind) }}
    {{- end }}
    {{- if and (and (ne $subjectKind "ServiceAccount"  ) (ne $subjectKind "User")) (ne $subjectKind "Group") }}
      {{- fail (printf "Not a valid Kind in subject: (%s); must be one of ServiceAccount, User, or Group")}}
    {{- end }}
    kind: {{ $subjectKind }}
    name: {{ $s.name }}
    namespace: {{ default $.Release.Namespace $s.namespace }}
  {{- end }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: {{ $roleKind }}
  name: {{ $values.roleRef.name }}
{{- end }}
