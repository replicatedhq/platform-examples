{{- /* The main container included in the main */ -}}
{{- define "replicated-library.initContainer" -}}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "app") -}}
    {{- $values = .ContextValues.app -}}
  {{- else -}}
    {{- fail "_init_container.tpl requires the 'app' ContextValues to be set" -}}
  {{- end -}}
  {{- $_ := set $.ContextValues "names" (dict "context" "app") -}}
{{- range $containerName, $containerValues := $values.initContainers }}
- name: {{ printf "%s" $containerName | trunc 63 | trimAll "-" }}
  image: {{ printf "%s:%s" $containerValues.image.repository (default $.Chart.AppVersion ($containerValues.image.tag | toString)) | quote }}
  imagePullPolicy: {{ default $.Values.defaults.image.pullPolicy $containerValues.image.pullPolicy }}
  {{- with $containerValues.command }}
  command:
    {{- if kindIs "string" . }}
    - {{ . }}
    {{- else }}
      {{ toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- with $containerValues.args }}
  args:
    {{- if kindIs "string" . }}
    - {{ . }}
    {{- else }}
    {{ toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- with $containerValues.securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $containerValues.lifecycle }}
  lifecycle:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- if $containerValues.termination }}
  {{- with $containerValues.termination.messagePath }}
  terminationMessagePath: {{ . }}
  {{- end }}
  {{- with $containerValues.termination.messagePolicy }}
  terminationMessagePolicy: {{ . }}
  {{- end }}
{{- end }}
  {{- with $containerValues.env }}
  env:
    {{- get (fromYaml (include "replicated-library.env_vars" .)) "env" | toYaml | nindent 4 -}}
  {{- end }}
  {{- if or $containerValues.envFrom $containerValues.secret }}
  envFrom:
    {{- with $containerValues.envFrom }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- with $containerValues.ports }}
  ports:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $containerValues.volumeMounts }}
  volumeMounts:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $containerValues.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end -}}
