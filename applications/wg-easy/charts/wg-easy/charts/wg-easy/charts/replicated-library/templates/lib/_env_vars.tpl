{{/*
Environment variables used by containers.
*/}}
{{- define "replicated-library.env_vars" -}}
  {{- $values := . -}}

  {{- with $values -}}
    {{- $result := list -}}
    {{- range $k, $v := . -}}
      {{- $name := $k -}}
      {{- $value := $v -}}
      {{- if kindIs "int" $name -}}
        {{- $name = required "environment variables as a list of maps require a name field" $value.name -}}
      {{- end -}}
      {{- if kindIs "string" $value -}}
      # string in values.yaml example: foo: bar 
        {{- $result = append $result (dict "name" $name "value" $value) -}}
      {{- else if or (kindIs "float64" $value) (kindIs "bool" $value) -}}
        {{- $result = append $result (dict "name" $name "value" ($value | toString)) -}}
      {{- else if kindIs "map" $value -}}
        # map in values.yaml with value example: 
        # - name: foo
        #   value: bar 
        {{- if hasKey $value "value" -}} 
          {{- $envValue := $value.value | toString -}}
          {{- $result = append $result (dict "name" $name "value" $envValue) -}}
        {{- else if hasKey $value "valueFrom" -}}
        # map in values.yaml with valueFrom example: 
        #  - name: MYSQL_ROOT_PASSWORD  # Renders & installs statefulset with said environment variable.
        #    valueFrom:
        #    secretKeyRef:
        #      name: mysql-auth
        #      key: MYSQL_ROOT_PASSWORD
          {{- $result = append $result (dict "name" $name "valueFrom" $value.valueFrom) -}}
        {{- else -}}
          {{- $result = append $result (dict "name" $name "valueFrom" $value) -}}
        {{- end -}}
      {{- else -}}
        {{- $result = append $result (dict "name" $name "value" $value) -}}
      {{- end -}}
    {{- end -}}
    {{- toYaml (dict "env" $result) | nindent 0 -}}
  {{- end -}}
{{- end -}}
