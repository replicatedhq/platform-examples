## Features

### Dynamic App Reload on Configuration Changes

By default, when configmaps and secrets are used in the `envFrom` or `volumes` section of an App, 
any changes to those objects will force a restart of the App's pods so that they receive the latest configuration.

```yaml
global:
  fullNameOverride: "-"

apps:
  vaultwarden:
    enabled: true
    type: deployment
    replicas: 1
    containers:
      vaultwarden:
        image:
          repository: vaultwarden/server
          tag: 1.27.0-alpine
        ports:
        - name: http
          containerPort: 80
        envFrom:
        - secretRef:
            name: vaultwarden
        volumeMounts:
        - mountPath: /randomPath/file.yaml
          subPath: file.yaml
          name: sample-configmap
    volumes:
    - name: sample-configmap
      configMap:
        name: sample-configmap
secrets:
  vaultwarden:
    enabled: true
    data:
      TEST_VAR: "some-value"
configmaps:
  sample-configmap:
    enabled: true
    data:
      file.yaml: "file contents go here"
```

With the above configuration, annotations containing a hash of the configmap and secret will be added to the pod template. When the configmap or secret changes, the pod will be restarted.

```
Annotations:      checksum/config-vaultwarden: some-hash
                  checksum/secret-sample-configmap: some-hash
```

**NOTE**: This feature is not yet supported when a configmap or secret is referenced in `env`.

#### Disabling App Reloads

You can disable App reloads when a ConfigMap or Secret changes with the `appReload` key globally or at the Secret/ConfigMap level. `appReload` when set on a ConfigMap or Secret takes precedence over `.Values.global.appReload`.

```yaml
global:
  labels: {}
  annotations: {}
  fullNameOverride: "-"
  appReload: true

secrets:
  vaultwarden:
    enabled: true
    appReload: false
    data:
      TEST_VAR: "some-value"

configmaps:
  sample-configmap:
    enabled: true
    appReload: true
    data:
      file.yaml: "file contents go here"
```

With the above configuration, App reloads would only take place for anything using the `sample-configmap` ConfigMap.

### App, Service, and Ingress Association 

The Replicated library allows you to easily associate a Service object to an App or a Ingress object to a Service.

#### Associating a Service to an App

When you use `appName` to associate a service to an App, the library will automatically configure the `labelSelector` for both the service and the app to match the App name. This allows you to easily associate a service to an App without having to manually configure the labelSelector.

```yaml
global:
  labels: {}
  annotations: {}
  fullNameOverride: "-"
apps:
  vaultwarden:
    enabled: true
    type: deployment
    replicas: 1
    containers:
      vaultwarden:
        image:
          repository: vaultwarden/server
          tag: 1.27.0-alpine
        ports:
        - name: http
          containerPort: 80
services:
  vaultwarden:
    enabled: true
    appName: ["vaultwarden"] #appName supports one or more app names
    type: ClusterIP
    ports:
      http:
        enabled: true
        port: 8080
        protocol: HTTP
        targetPort: 80
```

The result is a Service object that automatically sets `spec.selector` to one or more labels matching the apps in `appName`.

```yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
  ...
  labels:
  ...
  name: vaultwarden
spec:
  ports:
  - name: http
    port: 8080
    protocol: TCP
    targetPort: 80
  selector:
    app.kubernetes.io/instance: vaultwarden
    app.kubernetes.io/name: vaultwarden
  type: ClusterIP
```

#### Associating a Service to an Ingress

Similiar to `appName` for services, you can use `serviceName` to associate an ingress to a service.

```yaml
services:
  vaultwarden:
    enabled: true
    appName: ["vaultwarden"]
    type: ClusterIP
    ports:
      http:
        enabled: true
        port: 8080
        protocol: HTTP
        targetPort: 80
ingresses:
  vaultwarden:
    enabled: true
    serviceName: vaultwarden
    hosts:
      - host: vaultwarden.example.com
        paths:
          - path: /
            pathType: Prefix
            service:
              port: 8080
```

The result is an Ingress object that automatically configures  `backend.service.name` to what was specified in `serviceName`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
  ...
  labels:
  ...
  name: vaultwarden
spec:
  rules:
  - host: vaultwarden.example.com
    http:
      paths:
      - backend:
          service:
            name: vaultwarden
            port:
              number: 8080
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - vaultwarden.example.com
    secretName: vaultwarden-tls-secret
```
