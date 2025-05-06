## Advanced Templating

The library chart can cover a lot of ground, but you may have the need to bring your own templates, hardcode values that you don't want end-users to change, 
or write a conditional that's toggled with the contents of a variable in your values.yaml. Here we'll provide a few examples of how 
to implement this on top of the library chart.


### Bringing your own templates and manifests

Because the library chart is still helm, it doesn't prevent you from doing this in anyway. For example, let's say you need to create 
the below TLS secret for use in an ingress:

templates/tls.yaml
```yaml
{{$cert := genSelfSignedCert "yourapp.example.com" nil nil 730 }}
apiVersion: v1
data:
  tls.crt: {{ $cert.Cert | b64enc }}
  tls.key: {{ $cert.Key | b64enc }}
kind: Secret
metadata:
  name: yourapp-tls-secret
type: kubernetes.io/tls
```

And then you could use this secret in `ingresses` section of your values.yaml

values.yaml
```
ingresses:
  yourapp:
    enabled: true
    serviceName: yourapp
    hosts:
      - host: yourapp.example.com
        paths:
          - path: /
            pathType: Prefix
            service:
              port: 8080
    tls:
    - hosts:
        - yourapp.example.com
      secretName: yourapp-tls-secret
```

### Hardcoding values
You may have a need to hardcode certain config in your values.yaml that you don't want users to overwrite. You can use the `mergeOverwrite` function to do this:

values.yaml
```yaml
apps:
  yourapp:
    enabled: true
    type: deployment
    replicas: 1
    containers:
      yourapp:
        image:
          repository: yourapp/server
          tag: 1.27.0-alpine
        volumeMounts:
        - mountPath: /work-dir
          name: work-dir
    volumes:
    - name: work-dir
      emptyDir: {}
```

templates/all.yaml
```tpl
{{- define "youapp.hardcodedValues" -}}
apps:
  yourapp:
    enabled: true
    type: deployment
    containers:
      yourapp:
        volumeMounts:
        - mountPath: /data
          name: yourapp
    volumes:
    - name: yourapp
      persistentVolumeClaim:
        claimName: yourapp
{{- end -}}

{{- $_ := mergeOverwrite .Values (include "yourapp.hardcodedValues" . | fromYaml) -}}

{{- include "replicated-library.all" . }}
```

The computed values in this case would be:

```yaml
apps:
  yourapp:
    enabled: true
    type: deployment
    replicas: 1
    containers:
      yourapp:
        image:
          repository: yourapp/server
          tag: 1.27.0-alpine
        volumeMounts:
        - mountPath: /data
          name: yourapp
        - mountPath: /work-dir
          name: work-dir
    volumes:
    - name: work-dir
      emptyDir: {}
    - name: yourapp
      persistentVolumeClaim:
        claimName: yourapp
```

Regardless what the end user configures in the values.yaml for `yourapp`, the values you've hardcoded in your template will always be merged in and potentially overwrite.

### Adding a conditional
You can also use the hardcode values pattern to implement a conditional or other logic on top of the library chart:

values.yaml
```yaml
apps:
  yourapp:
    enabled: true
    type: deployment
    replicas: 1
    containers:
      yourapp:
        image:
          repository: yourapp/server
          tag: 1.27.0-alpine
yourAppConfig:
  enableSomeFeature: true
```

templates/all.yaml
```yaml
{{- define "youapp.hardcodedValues" -}}
apps:
  yourapp:
    enabled: true
    type: deployment
    replicas: 1
    containers:
      yourapp:
        image:
          repository: yourapp/server
          tag: 1.27.0-alpine
        {{- if .Values.yourAppConfig.enableSomeFeature -}}
        env:
          SOME_FEATURE: enabled
        {{- end -}}
{{- end -}}

{{- $_ := mergeOverwrite .Values (include "yourapp.hardcodedValues" . | fromYaml) -}}

{{- include "replicated-library.all" . }}
```

You've now created a new value specific to your helm chart which optionally enables an environment variable. And as we know from the first hardcoded values example,
the template including the conditional will merge and overwrite over the values in the `values.yaml`
