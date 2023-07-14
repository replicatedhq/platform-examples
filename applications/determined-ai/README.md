# Determined AI Example

[Determined AI](https://docs.determined.ai/latest/index.html)

This example shows how to package an application as a KOTS app using the [Replicated Library Chart](https://github.com/replicatedhq/helm-charts/tree/main/charts/replicated-library). Included are several practical examples of common patterns used when deploying a helm chart with KOTS.

# Table of Contents
* [Examples](#examples)
    * [Embedded vs. External Database](#embedded-vs-external-database)
    * [Self-signed Ingress TLS Certificate vs. User-provided](#self-signed-ingress-tls-certificate-vs-user-provided)
    * [Pass Labels and Annotations from Config Options to Helm Chart Values](#pass-labels-and-annotations-from-config-options-to-helm-chart-values)
    * [Wait for Database to Start Before Starting your Application](#wait-for-database-to-start-before-starting-your-application)

# Examples

All of the below examples are snippets from the full example chart in this directory

## Embedded vs. External Database

You may have the need to allow end-users to choose between hosting the database required by your application themselves or providing one with the application at install time. This example will show you how to package templates in your helm chart to allow this functionality for a Postgres database as well as how you would integrate it with your KOTS app.

1. First you'll need to template in your helm chart the optionality between "embedded" vs. "external" Postgres

[values.yaml](values.yaml)
```yaml
postgresql:
  # This is a subchart that we're importing from Bitnami
  enabled: true
  image:
    registry: docker.io
    repository: bitnami/postgresql
    tag: 15.3.0-debian-11-r0
  fullnameOverride: postgresql
  auth:
    postgresPassword: determined

determined:
  # Here is where we defined our custom values to implement our templating
  postgresPassword: determined
  externalPostgres:
    enabled: false
    username: postgres
    password: determined
    database: postgres
    host: postgresql
    port: 5432
```

**NOTE**: Determined AI uses a secret containing a config file where all of the application configuration lives including the database connection string. The below is a snippet from that configuration file where we are adding our templating. For you this same templating might be added in environment variables or elsewhere but the same logic applies.

[replicated-library.yaml](templates/replicated-library.yaml)
```yaml
secrets:
  determined:
    data:
      master.yaml: |
        db:
        {{- if .Values.determined.externalPostgres.enabled }}
          user: {{ required "A valid .Values.determined.externalPostgres.username entry required!" .Values.determined.externalPostgres.username | quote }}
          password: {{ required "A valid Values.determined.externalPostgres.password entry required!" .Values.determined.externalPostgres.password | quote }}
          host: {{ .Values.determined.externalPostgres.host }}
          port: {{ .Values.determined.externalPostgres.port }}
          name: {{ .Values.determined.externalPostgres.name | quote }}
        {{- else }}
          user: postgres
          password: {{ required "A valid Values.determined.postgresPassword entry required!" .Values.determined.postgresPassword | quote }}
          host: postgresql
          port: 5432
          name: postgres
        {{- end }}
```

2. Now that our templating is configured, we can use the new values that we've created for `externalPostgres` in our KOTS Config Options

[kots-config.yaml](manifests/kots-config.yaml)
```yaml
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

[kots-helm.yaml](manifests/kots-helm.yaml)
```yaml
apiVersion: kots.io/v1beta2
kind: HelmChart
metadata:
  name: determined
spec:
  values:
    postgresql:
      enabled: 'repl{{ (ConfigOptionEquals "postgres_type" "embedded_postgres") }}'
      auth:
        postgresPassword: 'repl{{ConfigOption "embedded_postgres_password"}}'
    
    determined:
      postgresPassword: 'repl{{ConfigOption "embedded_postgres_password"}}'
      externalPostgresql:
        enabled: repl{{ ConfigOptionEquals "postgres_type" "external_postgres" }}
        username: 'repl{{ ConfigOption "external_postgres_username" }}'
        password: 'repl{{ ConfigOption "external_postgres_password" }}'
        database: 'repl{{ ConfigOption "external_postgres_db" }}'
        host: 'repl{{ ConfigOption "external_postgres_host" }}'
        port: 'repl{{ ConfigOption "external_postgres_port" }}'
```

When the user sets the `postgres_type` to `external_postgres` in the KOTS config UI, additional config options are shown allowing them to specify the username, password, host, and port to connect to Postgres.

## Self-signed Ingress TLS Certificate vs. User-provided

If you are providing a TLS secret with your app to terminate TLS at the Ingress level, you will likely want the ability to let users decide between providing their own certificate vs. defaulting to a self-signed one.

1. Add the tls configuration to your helm chart values

[values.yaml](values.yaml)
```yaml
determined:
  tls:
    enabled: true
    genSelfSignedCert: false
    cert: |
      -----BEGIN CERTIFICATE-----
      -----END CERTIFICATE-----
    key: |
      -----BEGIN PRIVATE KEY-----
      -----END PRIVATE KEY-----
```

2. Add a tls secret to your chart and implement the templating to conditionally choose between user-provided and self-signed

[tls.yaml](templates/tls.yaml)
```yaml
{{- if .Values.determined.tls.enabled -}}
  {{- $cert := dict -}}
  {{- if .Values.determined.tls.genSelfSignedCert -}}
    {{ $cert = genSelfSignedCert "determined.example.com" nil nil 730 }}
  {{- else -}}
    {{- $_ := set $cert "Cert" .Values.determined.tls.cert -}}
    {{- $_ := set $cert "Key" .Values.determined.tls.key -}}
  {{- end -}}
apiVersion: v1
data:
  tls.crt: {{ $cert.Cert | b64enc }}
  tls.key: {{ $cert.Key | b64enc }}
kind: Secret
metadata:
  name: determined-tls
type: kubernetes.io/tls
{{- end -}}
```

3. In KOTS you can expose config options to allow a user to optionally upload a cert if the "User Provided" TLS option is selected

[kots-config.yaml](manifests/kots-config.yaml)
```yaml
apiVersion: kots.io/v1beta1
kind: Config
metadata:
  name: config
spec:
  groups:
  - name: ingress_settings
    title: Ingress Settings
    description: Configure Ingress for Determined
    items:
    - name: determined_ingress_tls_type
      title: Determined Ingress TLS Type
      type: select_one
      items:
      - name: self_signed
        title: Self Signed (Generate Self Signed Certificate)
      - name: user_provided
        title: User Provided (Upload a TLS Certificate and Key Pair)
      required: true
      default: self_signed
      when: 'repl{{ and (not IsKurl) (ConfigOptionEquals "determined_ingress_type" "ingress_controller") }}'
    - name: determined_ingress_tls_cert
      title: Determined TLS Cert
      type: file
      when: '{{repl and (ConfigOptionEquals "determined_ingress_type" "ingress_controller") (ConfigOptionEquals "determined_ingress_tls_type" "user_provided") }}'
      required: true
    - name: determined_ingress_tls_key
      title: Determined TLS Key
      type: file
      when: '{{repl and (ConfigOptionEquals "determined_ingress_type" "ingress_controller") (ConfigOptionEquals "determined_ingress_tls_type" "user_provided") }}'
      required: true
```

[kots-helm.yaml](manifests/kots-helm.yaml)
```yaml
apiVersion: kots.io/v1beta2
kind: HelmChart
metadata:
  name: determined
spec:
  values:
    determined:
      tls:
        enabled: repl{{ ConfigOptionEquals "determined_ingress_type" "ingress_controller" }}
        genSelfSignedCert: repl{{ ConfigOptionEquals "determined_ingress_tls_type" "self_signed" }}
        cert: repl{{ print `|`}}repl{{ ConfigOptionData `determined_ingress_tls_cert` | nindent 10 }}
        key: repl{{ print `|`}}repl{{ ConfigOptionData `determined_ingress_tls_key` | nindent 10 }}
```

## Pass Labels and Annotations from Config Options to Helm Chart Values

There may be a variety of different situations in which you'd want the user to be able to set annotations or labels on a resource you're deploying in your application. A good example is when you want the user to be able to set annotations on a `Service` or `Ingress` object in public cloud environments. The below shows how you can use Replicated's Config Options to do this.

1. Use the `textarea` config option type to allow a user to copy/paste in their annotations or labels

[kots-config.yaml](manifests/kots-config.yaml)
```yaml
apiVersion: kots.io/v1beta1
kind: Config
metadata:
  name: config
spec:
  groups:
  - name: ingress_settings
    title: Ingress Settings
    description: Configure Ingress for Determined
    items:
    - name: determined_load_balancer_annotations
      type: textarea
      title: Load Balancer Annotations
      help_text: See your cloud provider’s documentation for the required annotations.
      when: 'repl{{ and (not IsKurl) (ConfigOptionEquals "determined_ingress_type" "load_balancer") }}'
```

2. Use the config option you created in your KOTS helm chart values for the service annotations

[kots-helm.yaml](manifests/kots-helm.yaml)
```yaml
apiVersion: kots.io/v1beta2
kind: HelmChart
metadata:
  name: determined
spec:
  values:
    services:
      determined:
        enabled: true
        appName: ["determined"]
        annotations: repl{{ ConfigOption "determined_load_balancer_annotations" | nindent 10 }}
```

**NOTE**: The `| nindent 10` is important to ensure the annotation are formatted properly.

## Wait for Database to Start Before Starting your Application

A common pattern when you have an application that has a database dependency is to ensure that the database is healthy and accepting connections before starting the app. You can use [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) in Kubernetes to accomplish this. Our example defines an `initContainer` using the Replicated Library Chart that will wait for a Postgres database to start before proceeding to the primary container in the pod.

[replicated-library.yaml](templates/replicated-library.yaml)
```yaml
apps:
  determined:
    initContainers:
      1-postgres-wait:
        image:
          repository: docker.io/bitnami/postgresql
          tag: 15.3.0-debian-11-r0
        env:
        {{- if .Values.determined.externalPostgres.enabled }}
          POSTGRES_USER: {{ required "A valid .Values.determined.externalPostgres.username entry required!" .Values.determined.externalPostgres.username | quote }}
          POSTGRES_PASSWORD: {{ required "A valid Values.determined.externalPostgres.password entry required!" .Values.determined.externalPostgres.password | quote }}
          POSTGRES_HOST: {{ .Values.determined.externalPostgres.host }}
          POSTGRES_PORT: {{ .Values.determined.externalPostgres.port }}
          POSTGRES_DB: {{ .Values.determined.externalPostgres.name | quote }}
        {{- else }}
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: {{ required "A valid Values.determined.postgresPassword entry required!" .Values.determined.postgresPassword | quote }}
          POSTGRES_HOST: postgresql
          POSTGRES_PORT: 5432
          POSTGRES_DB: postgres
        {{- end }}
        command: ["sh", "-c", "until PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -h $POSTGRES_HOST -p 5432 -d $POSTGRES_DB -c 'SELECT 1'; do sleep 1; done;"]
```

Building off of the work done in [Embedded vs. External Database](#embedded-vs-external-database), we have an init container which will use the appropriate credentials to continously sleep until we have a successful query against the database.
