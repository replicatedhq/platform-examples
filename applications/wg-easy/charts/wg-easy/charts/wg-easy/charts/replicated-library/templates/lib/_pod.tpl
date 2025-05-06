{{- /*
The pod definition included in the main.
*/ -}}
{{- define "replicated-library.pod" -}}
  {{- $values := "" -}}
  {{- if and (hasKey . "ContextValues") (hasKey .ContextValues "app") -}}
    {{- $values = .ContextValues.app -}}
  {{- else -}}
    {{- fail "_pod.tpl requires the 'app' ContextValues to be set" -}}
  {{- end -}}
  {{- with $values.imagePullSecrets }}
imagePullSecrets:
    {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- if $values.serviceAccountName }}
    {{- /* Add the prefix to the serviceAccountName if it is in the serviceAccounts dict and is enabled */}}
      {{- if $.Values.serviceAccounts }}
        {{- if and (hasKey $.Values.serviceAccounts $values.serviceAccountName) (get (get $.Values.serviceAccounts $values.serviceAccountName) "enabled") -}}
          {{- $_ := set $values "serviceAccountName" (printf "%s-%s" (include "replicated-library.names.prefix" $) $values.serviceAccountName | trimAll "-") }}
        {{- end }}
      {{- end }}
serviceAccountName: {{ $values.serviceAccountName }}
  {{- end }}
automountServiceAccountToken: {{ $values.automountServiceAccountToken }}
  {{- with $values.podSecurityContext }}
securityContext:
    {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- with $values.priorityClassName }}
priorityClassName: {{ . }}
  {{- end }}
  {{- with $values.runtimeClassName }}
runtimeClassName: {{ . }}
  {{- end }}
  {{- with $values.schedulerName }}
schedulerName: {{ . }}
  {{- end }}
  {{- with $values.hostNetwork }}
hostNetwork: {{ . }}
  {{- end }}
  {{- with $values.hostname }}
hostname: {{ . }}
  {{- end }}
  {{- if $values.dnsPolicy }}
dnsPolicy: {{ $values.dnsPolicy }}
  {{- else if $values.hostNetwork }}
dnsPolicy: ClusterFirstWithHostNet
  {{- else }}
dnsPolicy: ClusterFirst
  {{- end }}
  {{- with $values.dnsConfig }}
dnsConfig:
    {{- toYaml . | nindent 2 }}
  {{- end }}
enableServiceLinks: {{ $values.enableServiceLinks }}
{{- if $values.termination }}
  {{- with $values.termination.gracePeriodSeconds }}
terminationGracePeriodSeconds: {{ . }}
  {{- end }}
{{- end }}
{{- if $values.initContainers }}
initContainers:
  {{- include "replicated-library.initContainer" . | nindent 2 }}
{{- end }}
containers:
  {{- include "replicated-library.container" . | trim | nindent 2 }}
  {{- with $values.volumes }}
volumes:
    {{- range . }} 
      {{- /* Add the prefix to the persistentVolumes if from this chart */}}
      {{- if (hasKey . "persistentVolumeClaim") -}}
        {{- if (hasKey .persistentVolumeClaim "claimName") -}}
          {{- if (hasKey $.Values.persistence .persistentVolumeClaim.claimName) }}
            {{- $globalVolume := get (get $.Values.persistence .persistentVolumeClaim.claimName) "persistentVolumeClaim" }}
            {{- if and (hasKey $globalVolume "existingClaim") $globalVolume.existingClaim -}}
              {{- /* Volume is an existing claim use that name */}}
              {{- $_ := set .persistentVolumeClaim "claimName" $globalVolume.existingClaim }}
            {{- else }}
              {{- /* Append the prefix */}}
              {{- $_ := set .persistentVolumeClaim "claimName" (printf "%s-%s" (include "replicated-library.names.prefix" $) .persistentVolumeClaim.claimName | trimAll "-") }}
            {{- end }}
          {{- end }}
        {{- end }}
      {{- end }}
      {{- /* Add the prefix to configMaps if from this chart */}}
      {{- if (hasKey . "configMap") -}}
        {{- if (hasKey .configMap "name") -}}
          {{- if and (hasKey $.Values.configmaps .configMap.name) (get (get $.Values.configmaps .configMap.name) "enabled") -}}
            {{- $_ := set .configMap "name" (printf "%s-%s" (include "replicated-library.names.prefix" $) .configMap.name | trimAll "-") }}
          {{- end }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- toYaml . | nindent 2}}
  {{- end }}
  {{- with $values.hostAliases }}
hostAliases:
    {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- with $values.nodeSelector }}
nodeSelector:
    {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- with $values.affinity }}
affinity:
    {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- with $values.topologySpreadConstraints }}
topologySpreadConstraints:
    {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- with $values.tolerations }}
tolerations:
    {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end -}}
