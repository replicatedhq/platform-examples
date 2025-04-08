# Task
- write a Helmfile to `./applications/n8n/charts/helmfile.yaml` that will install these charts in order: CloudNativePG --> Nginx Ingress Controller --> local n8n chart in charts/n8n
- leave the values empty to be populated later
- use this `helmDefaults`

```yaml
helmDefaults:
  wait: true
  timeout: 66
```