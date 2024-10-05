# Embedded vs. External Database

You may have the need to allow end-users to choose between hosting the database required by your application themselves or providing one with the application at install time. This example will show you how to package templates in your helm chart to allow this functionality for a Postgres database as well as how you would integrate it with your KOTS app.

Source Application: [Mlflow](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow)

1. First you'll need to template in your helm chart the optionality between "embedded" vs. "external" Postgres

[Mlflow Helm Values](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/chart/mlflow/values.yaml)
```yaml
postgres:
  auth:
    username: mlflow
    password: mlflow

  embedded:
    enabled: true
    type: postgresql

  external:
    enabled: false
    host: ""
    port: 5432
    database: mlflow
```

[Mlflow Secret](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/chart/mlflow/templates/secret.yaml)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "mlflow.fullname" . }}
  labels:
    {{- include "mlflow.labels" . | nindent 4 }}
type: Opaque
stringData:
  {{- $dbUri := (printf "postgresql://%s:%s@%s:%s/%s" .Values.postgres.auth.username .Values.postgres.auth.password (printf "%s-postgres-rw" (include "mlflow.fullname" .)) "5432" .Values.postgres.embedded.initdb.database) }}
  {{- if .Values.postgres.external.enabled }}
  {{- $dbUri = (printf "postgresql://%s:%s@%s:%s/%s" .Values.postgres.auth.username .Values.postgres.auth.password .Values.postgres.external.host .Values.postgres.external.port .Values.postgres.external.database) }}
  {{- end }}

  {{- /* Backend Store */}}
  {{- $modes := list "serve-artifacts" "no-serve-artifacts" }}
  {{- if has .Values.mlflow.trackingServer.mode $modes }}
  {{- if not .Values.mlflow.backendStore.existingSecret }}
  MLFLOW_BACKEND_STORE_URI: {{ $dbUri }}
  {{- end }}
  {{- end }}
```

2. Now that we've created the templates, we will create corresponding KOTS Config Options so that we can map them into our HelmChart resource

[Mlflow KOTS Config](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/kots/manifests/kots-config.yaml)
```yaml
apiVersion: kots.io/v1beta1
kind: Config
metadata:
  name: config
spec:
  groups:
  - name: database_settings
    title: Database
    items:
      - name: postgres_type
        help_text: Would you like to use an embedded postgres instance, or connect to an external instance that you manage?
        type: select_one
        title: Postgres
        default: embedded_postgres
        items:
            - name: embedded_postgres
            title: Embedded Postgres
            - name: external_postgres
            title: External Postgres
      - name: embedded_postgres_password
        hidden: true
        readonly: false
        type: password
        value: '{{repl RandomString 32}}'
      - name: embedded_postgres_volume_size
        title: Postgres Volume Size
        type: text
        default: "10Gi"
        when: '{{repl ConfigOptionEquals "postgres_type" "embedded_postgres"}}'
      - name: external_postgres_host
        title: Postgres Host
        when: '{{repl ConfigOptionEquals "postgres_type" "external_postgres"}}'
        type: text
        default: postgres
      - name: external_postgres_port
        title: Postgres Port
        when: '{{repl ConfigOptionEquals "postgres_type" "external_postgres"}}'
        type: text
        default: "5432"
      - name: external_postgres_username
        title: Postgres Username
        when: '{{repl ConfigOptionEquals "postgres_type" "external_postgres"}}'
        type: text
        required: true
      - name: external_postgres_password
        title: Postgres Password
        when: '{{repl ConfigOptionEquals "postgres_type" "external_postgres"}}'
        type: password
        required: true
      - name: external_postgres_db
        title: Postgres Database
        when: '{{repl ConfigOptionEquals "postgres_type" "external_postgres"}}'
        type: text
        default: postgres
```

**Note**: We have the proper `when` statements in place to ensure that the external Postgres Config Options aren't used if that deployment type isn't enabled.

[Mlflow KOTS Helm Chart](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/kots/manifests/helm-mlflow.yaml)
```yaml
apiVersion: kots.io/v1beta2
kind: HelmChart
metadata:
  name: mlflow
spec:
  chart:
    name: mlflow
    chartVersion: 0.1.2
  weight: 1
  values:
    postgres:
      auth:
        password: repl{{ ConfigOption "embedded_postgres_password"}}
      embedded:
        enabled: repl{{ ConfigOptionEquals "postgres_type" "embedded_postgres" }}
        storage:
          size: repl{{ ConfigOption "embedded_postgres_volume_size"}}
  optionalValues:
    - when: 'repl{{ ConfigOptionEquals "postgres_type" "external_postgres" }}'
      recursiveMerge: true
      values:
        postgres:
          auth:
            username: repl{{ ConfigOption "external_postgres_username"}}
            password: repl{{ ConfigOption "external_postgres_password"}}
          embedded:
            enabled: false
          external:
            enabled: true
            host: repl{{ ConfigOption "external_postgres_host"}}
            port: repl{{ ConfigOption "external_postgres_port"}}
            database: repl{{ ConfigOption "external_postgres_db"}}
```

When the user sets the `postgres_type` to `external_postgres` in the KOTS config UI, additional config options are shown allowing them to specify the username, password, host, and port to connect to Postgres.
