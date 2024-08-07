# Multiple Chart Orchestation

In some cases, your application cannot be contained within a single Helm chart due to orchestration requirements. This can happen for a variety of reasons, such as distributing operators in one set of charts and the applications that rely on them in another. This guide will demonstrate how to orchestrate the installation of multiple Helm charts using KOTS (Kubernetes Off-The-Shelf). Additionally, it will cover the use of Helm hooks to verify the existence of necessary resources in the cluster, ensuring that all dependencies are met for a successful application installation.

Source Application: [Mlflow](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow)

## Why the Mlflow application needs orchestration

Mlflow requires dependencies on PostgreSQL and S3-compatible object storage. To meet this requirement and allow users to install the application without setting up these dependencies separately, Mlflow bundles PostgreSQL and Minio along with the application. This is achieved using the [Cloudnative-PG](https://github.com/cloudnative-pg/cloudnative-pg) for PostgreSQL and the [Minio Operator](https://github.com/minio/operator/tree/master) for Minio.

When distributing operators that install Custom Resource Definitions (CRDs) alongside applications that create custom resources from those CRDs, orchestration is generally required. This ensures that all components are installed in the correct order and that the necessary dependencies are present for the application to function correctly.

## KOTS HelmChart Weight and Helm Upgrade Flags

The weight property in the Replicated [HelmChart](https://docs.replicated.com/reference/custom-resource-helmchart-v2) custom resource allows you to control the order in which Helm charts are installed. KOTS installs Helm charts based on the weight value in ascending order, meaning that charts with lower weight values are installed first.

You can set the weight property to any negative or positive integer, or 0. By default, if no weight is specified, the weight is set to 0.

[Infra HelmChart](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/kots/infra-chart.yaml)
```yaml
apiVersion: kots.io/v1beta2
kind: HelmChart
metadata:
  name: infra
spec:
  chart:
    name: infra
    chartVersion: 0.1.0
  weight: -10
  helmUpgradeFlags:
    - --wait
    - --timeout
    - 600s
```

[Mlflow HelmChart](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/kots/mlflow-chart.yaml)
```yaml
apiVersion: kots.io/v1beta2
kind: HelmChart
metadata:
  name: mlflow
spec:
  chart:
    name: mlflow
    chartVersion: 0.3.0
  weight: 10
  helmUpgradeFlags:
    - --wait
    - --timeout
    - 600s
```

In the above two snippets, the `infra` chart that we're installing with KOTS includes the Cloudnative-PG operator for Postgres as well as the Minio Operator. Because the weight in the `infra` chart is set to `-10` which is lower than a value of `10` that Mlflow uses, it will be installed first.

In this example, we're also using `helmUpgradeFlags` to specify additional flags to pass to the Helm upgrade command for charts. These flags are passed in addition to any flags KOTS passes by default. The values specified here take precedence if KOTS already passes the same flag. We're setting the Helm `--wait` flag to ensure that Helm waits until all Kubernetes resources are in a ready state before marking the release as successful. Additionally, we're setting a timeout for the wait flag to define the maximum amount of time to wait for the resources to become ready.

To see more info on resource orchestration in KOTS as well as the reference for `kind: HelmChart`, visit the following two articles:

https://docs.replicated.com/vendor/orchestrating-resource-deployment

https://docs.replicated.com/reference/custom-resource-helmchart-v2

## Validate existence of CRDs with Helm Hooks

Helm hooks allow you to execute custom actions at specific points in a chart's lifecycle. For example, you can use hooks to perform actions before or after installation, upgrade, or deletion.

The `infra` chart includes a `post-install` and `post-upgrade` hook that checks for Custom Resource Definitions (CRDs). Combined with the `--wait` flag used in the `helmUpgradeFlags`, and the fact that we always install the `infra` chart first, ensures that the CRDs are registered before the installation of the application chart begins.

[Infra Chart CRD Check Job](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/chart/infra/templates/crd-check-job.yaml)
```yaml
{{- if .Values.crdCheck.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "crdCheck.fullname" . }}
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      serviceAccountName: {{ include "crdCheck.fullname" . }}
      {{- with .Values.crdCheck.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
      - name: crd-check
        image: "{{ .Values.crdCheck.image.registry | default "docker.io" }}/{{ .Values.crdCheck.image.repository }}:{{ .Values.crdCheck.image.tag | default (printf "v%s" .Chart.AppVersion) }}"
        command:
        - /bin/bash
        - -c
        - |
          TIMEOUT={{ .Values.crdCheck.timeout }}
          START_TIME=$(date +%s)
          CRDS=({{ range .Values.crdCheck.crds }} "{{ .name }}" {{ end }})
          for CRD_NAME in "${CRDS[@]}"; do
            while true; do
              if kubectl get crd $CRD_NAME -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' | grep -q "True"; then
                echo "CRD $CRD_NAME is established."
                break
              fi
              if [ $(($(date +%s) - $START_TIME)) -ge $TIMEOUT ]; then
                echo "Timeout: CRD $CRD_NAME was not established within $TIMEOUT seconds."
                exit 1
              fi
              echo "Waiting for CRD $CRD_NAME to be created and established...";
              sleep 5;
            done
          done
          exit 0
      restartPolicy: OnFailure
{{- end }}
```

[Infra Chart Values](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/chart/infra/values.yaml)
```yaml
crdCheck:
  enabled: true
  image:
    registry: docker.io
    repository: bitnami/kubectl
    tag: latest
  crds:
    - name: tenants.minio.min.io
    - name: clusters.postgresql.cnpg.io
  timeout: 60
  imagePullSecrets: []
```
