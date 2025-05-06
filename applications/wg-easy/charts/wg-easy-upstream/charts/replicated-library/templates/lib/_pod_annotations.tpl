{{/* Determine the Pod annotations used in the main */}}
{{- define "replicated-library.podAnnotations" -}}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "app") -}}
    {{- $values = .ContextValues.app -}}
  {{- else -}}
    {{- fail "_pod_annotations.tpl requires the 'app' ContextValues to be set" -}}
  {{- end -}}

  {{- if $values.podAnnotations }}
    {{- tpl (toYaml $values.podAnnotations) . | nindent 0 }}
  {{- end }}

  {{- $configMapsFound := false -}}
  {{- range $name, $configmap := .Values.configmaps -}}
    {{- if $configmap.enabled -}}
      {{- $configMapsFound = true -}}
    {{- end -}}
  {{- end -}}
  {{- if $configMapsFound -}}
    {{- include ("replicated-library.podAnnotations.shaAnnotations") . -}}
  {{- end -}}
{{- end -}}

{{- define "replicated-library.podAnnotations.shaAnnotations" -}}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "app") -}}
    {{- $values = .ContextValues.app -}}
  {{- else -}}
    {{- fail "_pod_annotations.tpl requires the 'app' ContextValues to be set" -}}
  {{- end -}}
  
  {{- $prefix := include "replicated-library.names.prefix" . -}}
  {{- $configMapsFound := dict -}}
  {{- $secretsFound := dict -}}

  {{- if hasKey $values "volumes" -}}
    {{- range $i, $v := $values.volumes -}}
      {{- if hasKey $v "configMap" -}}
        {{- $fullName := (printf "%s-%s" $prefix $v.configMap.name | trunc 63 | trimAll "-") -}}
        {{- $_ := set $configMapsFound $fullName true -}}
      {{- end -}}
      {{- if hasKey $v "secret" -}}
        {{- $fullName := (printf "%s-%s" $prefix $v.secret.secretName | trunc 63 | trimAll "-") -}}
        {{- $_ := set $secretsFound $fullName true -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- range $container, $containerValues := $values.containers -}}
    {{- if hasKey $containerValues "envFrom" -}}
      {{- range $i, $v := $containerValues.envFrom -}}
        {{- if hasKey $v "configMapRef" -}}
          {{- $fullName := (printf "%s-%s" $prefix $v.configMapRef.name | trunc 63 | trimAll "-") -}}
          {{- $_ := set $configMapsFound $fullName true -}}
        {{- end -}}
        {{- if hasKey $v "secretRef" -}}
          {{- $fullName := (printf "%s-%s" $prefix $v.secretRef.name  | trunc 63 | trimAll "-") -}}
          {{- $_ := set $secretsFound $fullName true -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- $appReload := .Values.global.appReload -}}
  {{- range $configMapFound, $v := $configMapsFound -}}
    {{- range $configMapName, $configMapValues := $.Values.configmaps -}}
      {{- if (hasKey $configMapValues "appReload") -}}
        {{- $appReload = $configMapValues.appReload -}}
      {{- end -}}
      {{- if and $configMapValues.enabled $appReload -}}
        {{- $configMapFullName := (printf "%s-%s" $prefix $configMapName | trunc 63 | trimAll "-") -}}
        {{- if eq $configMapFound $configMapFullName -}}
          {{- printf "checksum/config-%v: %v" $configMapFullName (printf "%v" ($configMapValues.data) | sha256sum) | nindent 0 -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- range $secretFound, $v := $secretsFound -}}
    {{- range $secretName, $secretValues := $.Values.secrets -}}
      {{- if (hasKey $secretValues "appReload") -}}
        {{- $appReload = $secretValues.appReload -}}
      {{- end -}}
      {{- if and $secretValues.enabled $appReload -}}
        {{- $secretFullName := (printf "%s-%s" $prefix $secretName | trunc 63 | trimAll "-") -}}
        {{- if eq $secretFound $secretFullName -}}
          {{- printf "checksum/secret-%v: %v" $secretFullName (printf "%v" ($secretValues.data) | sha256sum) | nindent 0 -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
