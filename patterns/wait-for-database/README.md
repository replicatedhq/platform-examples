# Wait for Database to Start Before Starting your Application

A common pattern when you have an application that has a database dependency is to ensure that the database is healthy and accepting connections before starting the app. You can use [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) in Kubernetes to accomplish this. Our example defines an `initContainer` that will wait for a Postgres database to start before proceeding to the primary container in the pod.

Source Application: [Mlflow](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow)

[Mlflow Deployment YAML](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/chart/mlflow/templates/deployment.yaml)
```yaml
initContainers:
{{- if .Values.mlflow.trackingServer.basicAuth.enabled }}
{{- if not .Values.mlflow.trackingServer.basicAuth.existingSecret }}
- name: wait-for-postgresql
  image: docker.io/bitnami/postgresql:15.3.0-debian-11-r0
  imagePullPolicy: {{ .Values.mlflow.image.pullPolicy }}
  command: ["sh", "-c", "until PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -h $POSTGRES_HOST -p 5432 -d $POSTGRES_DB -c 'SELECT 1'; do sleep 1; done;"]
  envFrom:
  - secretRef:
      name: {{ printf "%s-waitfor-postgres" (include "mlflow.fullname" .)  | trunc 63 | trimAll "-" }}
```
