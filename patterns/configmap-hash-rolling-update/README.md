# Force a Deployment Rolling Update When a ConfigMap or Secret Changes

Kubernetes does not automatically restart Pods when a ConfigMap or Secret they reference is updated. This means that after a `helm upgrade` that only changes configuration values, your running Pods will continue using the old configuration until they are restarted for some other reason.

A reliable way to solve this is to include a checksum annotation on the Pod template. When the content of the ConfigMap or Secret changes, the checksum changes, Kubernetes sees a new Pod spec, and a rolling update is triggered automatically.

Source Application: [Mlflow](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow)

## Why Pods Don't Restart on ConfigMap Changes

When a Deployment mounts a ConfigMap through `envFrom` or `volumeMounts`, Kubernetes treats the ConfigMap reference as a pointer. Updating the ConfigMap's data does not change the Deployment's Pod spec, so no rollout is triggered. The same applies to Secrets.

This is by design -- Kubernetes separates configuration delivery from workload lifecycle management. But for most applications, stale configuration is a problem.

## The Pattern

Add a `checksum/*` annotation to `spec.template.metadata.annotations` that hashes the rendered content of each ConfigMap or Secret your Deployment depends on. When Helm re-renders the templates during an upgrade, any change to the ConfigMap or Secret content produces a different hash, which changes the Pod spec and triggers a rolling update.

## How It Works in Practice

The Mlflow chart uses `envFrom` to inject configuration from both a ConfigMap and Secrets into the application container:

[Mlflow Deployment - Container envFrom](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/charts/mlflow/templates/deployment.yaml)
```yaml
      containers:
      - name: {{ include "mlflow.fullname" . }}
        envFrom:
        - configMapRef:
            name: {{ include "mlflow.fullname" . }}
        - secretRef:
            name: {{ include "mlflow.fullname" . }}
```

The ConfigMap holds non-sensitive environment variables (artifact store endpoints, feature flags), while the Secret holds the database connection URI and credentials:

[Mlflow ConfigMap](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/charts/mlflow/templates/configmap.yaml)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mlflow.fullname" . }}
  labels:
    {{- include "mlflow.labels" . | nindent 4 }}
data:
  {{- with .Values.mlflow.env.configMap }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
```

To ensure the Deployment rolls when any of this configuration changes, the Pod template includes checksum annotations that hash the full rendered content of each dependent resource:

[Mlflow Deployment - Checksum Annotations](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/charts/mlflow/templates/deployment.yaml)
```yaml
  template:
    metadata:
      annotations:
        checksum/configmap: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        checksum/secret: {{ include (print $.Template.BasePath "/secret.yaml") . | sha256sum }}
        checksum/mlflow-auth-secret: {{ include (print $.Template.BasePath "/mlflow-auth-secret.yaml") . | sha256sum }}
```

Each annotation uses `include` to render the full template file and pipes the result through `sha256sum`. This means:

- Changing a value in `mlflow.env.configMap` changes the ConfigMap content, which changes the `checksum/configmap` hash, which updates the Pod spec, which triggers a rolling update.
- Changing the database password changes the Secret content, which changes the `checksum/secret` hash, triggering the same rollout.
- The auth secret gets its own checksum so that rotating basic auth credentials also triggers a restart.

## Variations

Different charts in this repository use slightly different approaches to the same pattern:

**Hash the rendered template file** (used by Mlflow and Gitea):
```yaml
checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```
This hashes the entire rendered YAML file, including metadata and labels. Any change to the template output triggers a rollout.

**Hash specific values** (used by n8n):
```yaml
checksum/config: {{ print .Values.main | sha256sum }}
```
This hashes only the values that feed into the configuration. It is simpler but may miss changes introduced through template logic rather than values.

## Key Considerations

- **One annotation per resource.** Use separate `checksum/*` keys for each ConfigMap and Secret so you can tell which resource triggered the rollout.
- **Hash the template, not the values.** Hashing the full `include` output (as Mlflow does) catches changes from template logic, conditionals, and helper functions -- not just direct value changes.
- **This only works with Helm-managed resources.** If a ConfigMap is created outside of Helm (by an operator, a CI job, etc.), the checksum annotation will not detect those changes.
- **Rolling updates respect your update strategy.** The rollout follows the Deployment's `strategy` configuration (`maxSurge`, `maxUnavailable`), so Pods are replaced gracefully.
