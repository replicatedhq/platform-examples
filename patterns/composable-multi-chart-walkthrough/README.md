# Composable Multi-Chart Walkthrough

This walkthrough traces the complete data flow of a composable multi-chart Replicated application, from individual chart structure through helmfile orchestration to release assembly. It uses the [wg-easy](https://github.com/replicatedhq/platform-examples/tree/main/applications/wg-easy) application as a concrete example throughout.

Reading order follows the data flow: chart structure, per-chart Replicated artifacts, helmfile orchestration, release assembly.

Source Application: [wg-easy](https://github.com/replicatedhq/platform-examples/tree/main/applications/wg-easy)

## Anatomy of a Wrapped Chart

Each chart under `charts/` wraps an upstream Helm chart (or uses a library chart) and carries its own Replicated artifacts. The wg-easy chart demonstrates the pattern:

```
charts/wg-easy/
  Chart.yaml                        # Declares dependencies
  values.yaml                       # Configures the library chart
  templates/
    common.yaml                     # Single-line loader for bjw-s/common
    _supportbundle.tpl              # Support bundle spec (named template)
    _preflight.tpl                  # Preflight check spec (named template)
    secret-supportbundle.yaml       # Renders support bundle into a Secret
    secret-preflights.yaml          # Renders preflight into a Secret
  replicated/
    config.yaml                     # Config screen items owned by this chart
    helmChart-wg-easy.yaml          # HelmChart CR with weight, namespace, template functions
```

### Chart.yaml: Declaring Dependencies

[wg-easy Chart.yaml](https://github.com/replicatedhq/platform-examples/blob/main/applications/wg-easy/charts/wg-easy/Chart.yaml)

```yaml
apiVersion: v2
dependencies:
- name: common
  repository: https://bjw-s-labs.github.io/helm-charts
  version: 3.7.3
- name: templates
  version: '*'
  repository: file://../templates
name: wg-easy
version: 1.0.0
```

Two dependencies serve different purposes:

- **`common`** is the [bjw-s app-template](https://github.com/bjw-s-labs/helm-charts) library chart. Instead of writing Kubernetes manifests directly, you declare controllers, services, persistence, and secrets in `values.yaml` and the library generates all the resources.
- **`templates`** is a local shared chart (described in a later section) that provides Traefik route generation and image pull secret creation across all charts.

### templates/common.yaml: The Loader

The entire template directory for the wg-easy chart revolves around a single entry point:

[wg-easy common.yaml](https://github.com/replicatedhq/platform-examples/blob/main/applications/wg-easy/charts/wg-easy/templates/common.yaml)

```yaml
{{- include "bjw-s.common.loader.init" . }}

{{- define "app-template.hardcodedValues" -}}
{{ if not .Values.global.nameOverride }}
global:
  nameOverride: "{{ .Release.Name }}"
{{ end }}
{{- end -}}
{{- $_ := mergeOverwrite .Values (include "app-template.hardcodedValues" . | fromYaml) -}}

{{ include "bjw-s.common.loader.generate" . }}
```

This initializes the bjw-s common library, sets a name override, and generates all Kubernetes resources from `values.yaml`. The chart has no other resource templates besides the support bundle and preflight secrets.

### replicated/config.yaml: Per-Chart Config Screen Items

[wg-easy config.yaml](https://github.com/replicatedhq/platform-examples/blob/main/applications/wg-easy/charts/wg-easy/replicated/config.yaml)

```yaml
apiVersion: kots.io/v1beta1
kind: Config
metadata:
  name: not-used
spec:
  groups:
    - name: wireguard-config
      title: Wireguard
      description: Wireguard configuration
      items:
      - name: password
        title: Admin password
        type: password
        required: true
      - name: domain
        title: IP or domain
        help_text: Domain or IP which the vpn is accessible on
        type: text
        required: true
      - name: vpn-port
        title: vpn port
        help_text: This port must be accessible remotely
        type: text
        default: "20000"
```

Each chart defines only the config items it owns. At release time, `task release-prepare` merges all per-chart `config.yaml` files into a single unified configuration screen.

### replicated/helmChart-wg-easy.yaml: The HelmChart Custom Resource

[wg-easy HelmChart CR](https://github.com/replicatedhq/platform-examples/blob/main/applications/wg-easy/charts/wg-easy/replicated/helmChart-wg-easy.yaml)

```yaml
apiVersion: kots.io/v1beta2
kind: HelmChart
metadata:
  name: wg-easy
spec:
  chart:
    name: wg-easy
  weight: 3
  helmUpgradeFlags:
    - --skip-crds
    - --timeout
    - 30s
    - --history-max=15
    - --wait
  values:
    wireguard:
      password: repl{{ ConfigOption `password` }}
      host: repl{{ ConfigOption `domain` }}
      port: repl{{ ConfigOption `vpn-port` | ParseInt }}
    controllers:
      wg-easy:
        containers:
          wg-container:
            image:
              repository: '{{repl HasLocalRegistry | ternary LocalRegistryHost "ghcr.io" }}/{{repl HasLocalRegistry | ternary LocalRegistryNamespace "wg-easy" }}/wg-easy'
    defaultPodOptions:
      imagePullSecrets:
        - name: '{{repl ImagePullSecretName }}'
  namespace: wg-easy
  builder: {}
```

Key fields:

- **`weight: 3`** controls installation order. Lower weights install first. cert-manager uses weight 0, so it installs before wg-easy.
- **`repl{{ ConfigOption ... }}`** maps config screen values into Helm values at install time.
- **`HasLocalRegistry`/`LocalRegistryHost`/`LocalRegistryNamespace`** handle air-gapped environments where images are pushed to a local registry.
- **`ImagePullSecretName`** references the pull secret Replicated injects for registry authentication.
- **`namespace`** declares the target namespace. The release-prepare task extracts these to populate `additionalNamespaces` in `application.yaml`.

### Contrast: cert-manager as an Infrastructure Chart

The same pattern applies to infrastructure charts. cert-manager wraps the upstream Jetstack chart:

[cert-manager Chart.yaml](https://github.com/replicatedhq/platform-examples/blob/main/applications/wg-easy/charts/cert-manager/Chart.yaml)

```yaml
name: cert-manager
apiVersion: v2
version: 1.0.0
dependencies:
  - name: cert-manager
    version: '1.14.5'
    repository: https://charts.jetstack.io
  - name: templates
    version: '*'
    repository: file://../templates
```

[cert-manager HelmChart CR](https://github.com/replicatedhq/platform-examples/blob/main/applications/wg-easy/charts/cert-manager/replicated/helmChart-cert-manager.yaml)

```yaml
apiVersion: kots.io/v1beta2
kind: HelmChart
metadata:
  name: cert-manager
spec:
  chart:
    name: cert-manager
  weight: 0
  helmUpgradeFlags:
    - --wait
  values:
    cert-manager:
      image:
        registry: '{{repl HasLocalRegistry | ternary LocalRegistryHost "quay.io" }}'
        repository: '{{repl HasLocalRegistry | ternary LocalRegistryNamespace "jetstack" }}/cert-manager-controller'
      # ... additional image rewrites for webhook, cainjector, acmesolver, startupapicheck
  namespace: cert-manager
  builder: {}
```

The differences are structural, not conceptual: cert-manager uses `weight: 0` to install before the application, wraps a different upstream chart, and rewrites different image repositories. The pattern of per-chart HelmChart CR with its own namespace, weight, and image rewrites is identical.

## Per-Chart Support Bundles and Preflights

Support bundles and preflights follow a define-render-secret pattern that lets each chart own its own diagnostics without a central manifest.

### The Pattern

1. **`_supportbundle.tpl`** defines a named Helm template containing a `troubleshoot.sh/v1beta2` SupportBundle spec.
2. **`secret-supportbundle.yaml`** renders that template into a Kubernetes Secret labeled `troubleshoot.sh/kind: support-bundle`.
3. Same structure for preflights: **`_preflight.tpl`** and **`secret-preflights.yaml`** with label `troubleshoot.sh/kind: preflight`.

Replicated auto-discovers these labeled secrets across all namespaces. No central manifest is needed.

### wg-easy: IP Forwarding Check

[wg-easy _supportbundle.tpl](https://github.com/replicatedhq/platform-examples/blob/main/applications/wg-easy/charts/wg-easy/templates/_supportbundle.tpl)

```yaml
{{- define "wg-easy.supportbundle" -}}
apiVersion: troubleshoot.sh/v1beta2
kind: SupportBundle
metadata:
  name: wg-easy-supportbundle
spec:
  collectors:
    - logs:
        namespace: {{ .Release.Namespace }}
        selector:
        - app.kubernetes.io/name=wg-easy
    - sysctl:
        image: debian:buster-slim
  analyzers:
    - sysctl:
        checkName: IP forwarding enabled
        outcomes:
          - fail:
              when: 'net.ipv4.ip_forward == 0'
              message: "IP forwarding must be enabled..."
          - pass:
              when: 'net.ipv4.ip_forward == 1'
              message: "IP forwarding is enabled."
{{- end -}}
```

[wg-easy secret-supportbundle.yaml](https://github.com/replicatedhq/platform-examples/blob/main/applications/wg-easy/charts/wg-easy/templates/secret-supportbundle.yaml)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: wg-easy-supportbundle
  labels:
    troubleshoot.sh/kind: support-bundle
type: Opaque
stringData:
  support-bundle-spec: |
{{ include "wg-easy.supportbundle" . | indent 4 }}
```

The wg-easy support bundle collects pod logs and sysctl values. The analyzer checks that IP forwarding is enabled, which WireGuard requires.

### cert-manager: Cluster Version Check

[cert-manager _preflight.tpl](https://github.com/replicatedhq/platform-examples/blob/main/applications/wg-easy/charts/cert-manager/templates/_preflight.tpl)

```yaml
{{- define "cert-manager.preflight" -}}
apiVersion: troubleshoot.sh/v1beta2
kind: Preflight
metadata:
  name: cert-manager-preflights
spec:
  analyzers:
    - clusterVersion:
        outcomes:
          - fail:
              when: "< 1.22.0"
              message: The application requires at least Kubernetes 1.22.0, and recommends 1.25.0.
          - warn:
              when: "< 1.25.0"
              message: Your cluster meets the minimum version of Kubernetes, but we recommend you update to 1.25.0 or later.
          - pass:
              message: Your cluster meets the recommended and required versions of Kubernetes.
{{- end -}}
```

A completely different check -- Kubernetes version instead of sysctl -- but the same define-render-secret structure. Each chart owns the diagnostics relevant to its component.

## The Shared Templates Chart

The `charts/templates/` directory is a Helm library chart included as a dependency by every other chart:

[templates Chart.yaml](https://github.com/replicatedhq/platform-examples/blob/main/applications/wg-easy/charts/templates/Chart.yaml)

```yaml
apiVersion: v2
appVersion: latest
description: Common templates
name: templates
version: 1.1.0
kubeVersion: ">=1.16.0-0"
```

It provides two capabilities:

### Traefik IngressRoute Generation

[templates/traefik-routes.yaml](https://github.com/replicatedhq/platform-examples/blob/main/applications/wg-easy/charts/templates/templates/traefik-routes.yaml) iterates over `.Values.traefikRoutes` and generates Traefik `IngressRoute` resources. Charts configure routes through values:

```yaml
# In wg-easy values.yaml
templates:
  traefikRoutes:
    web-tls:
      hostName: '{{ dig "wireguard" "host" "example.com" .Values }}'
      serviceName: wg-easy
      servicePort: 51821
```

This avoids every chart duplicating Traefik IngressRoute boilerplate.

### Image Pull Secret for Replicated Environments

[templates/imagepullsecret.yaml](https://github.com/replicatedhq/platform-examples/blob/main/applications/wg-easy/charts/templates/templates/imagepullsecret.yaml) creates a `kubernetes.io/dockerconfigjson` Secret when enabled:

```yaml
{{ if dig "replicated" "imagePullSecret" "enabled" false .Values.AsMap }}
apiVersion: v1
kind: Secret
metadata:
  name: replicated-pull-secret
  namespace: {{ .Release.Namespace }}
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: {{ .Values.global.replicated.dockerconfigjson }}
{{ end }}
```

In the `default` helmfile environment, this is disabled. In the `replicated` environment, helmfile sets `templates.replicated.imagePullSecret.enabled: true` and the Replicated platform injects the `dockerconfigjson` value.

## Helmfile: Two Environments, One Orchestration

The [helmfile.yaml.gotmpl](https://github.com/replicatedhq/platform-examples/blob/main/applications/wg-easy/helmfile.yaml.gotmpl) is the central orchestration file. It defines how charts are deployed in both local development and customer-facing Replicated environments.

### Global Defaults

```yaml
helmDefaults:
  verify: false
  wait: true
  timeout: 600
  atomic: true
  cleanupOnFail: true
```

Every release waits for resources to become ready, rolls back on failure, and cleans up failed resources.

### The `default` Environment

```yaml
environments:
  default:
    values:
      - chartSources:
          certManager: ./charts/cert-manager
          certManagerIssuers: ./charts/cert-manager-issuers
          traefik: ./charts/traefik
          wgEasy: ./charts/wg-easy
          replicatedSDK: ./charts/replicated
      - chartVersions:
          certManager: '{{ exec "yq" (list ".version" "./charts/cert-manager/Chart.yaml") }}'
          # ... same for each chart
      - extras:
          enableReplicatedSDK: false
```

Charts are installed from local paths on disk. The Replicated SDK is disabled. Chart versions are read dynamically from each `Chart.yaml` using `yq` at deploy time.

### The `replicated` Environment

```yaml
  replicated:
    values:
      - app: '{{ env "REPLICATED_APP" | default "wg-easy-cre" }}'
      - channel: '{{ env "CHANNEL" | default "unstable" }}'
      - username: '{{env "REPLICATED_LICENSE_ID"}}'
      - password: '{{env "REPLICATED_LICENSE_ID"}}'
      - chartSources:
          certManager: 'oci://registry.replicated.com/{{ env "REPLICATED_APP" | default "wg-easy-cre" }}/{{ env "CHANNEL" | default "unstable" }}/cert-manager'
          # ... same pattern for each chart
      - extras:
          enableReplicatedSDK: true
      - proxyImages:
          wgEasy:
            image:
              repository: proxy.replicated.com/proxy/wg-easy-cre/ghcr.io/wg-easy/wg-easy
          # ... proxy rewrites for traefik, cert-manager images
```

Charts are pulled from the Replicated OCI registry, authenticated with a customer license ID. Container images are routed through the Replicated registry proxy (`proxy.replicated.com/proxy/<app>/...`). The SDK is enabled.

### Release Ordering with `needs:`

```yaml
releases:
  - name: cert-manager
    namespace: cert-manager
    chart: {{ .Values.chartSources.certManager }}
    # ...

  - name: cert-manager-issuers
    namespace: cert-manager
    needs:
      - cert-manager/cert-manager

  - name: traefik
    namespace: traefik
    needs:
      - cert-manager/cert-manager-issuers

  - name: replicated
    namespace: replicated
    installed: {{ .Values.extras.enableReplicatedSDK }}
    needs:
      - traefik/traefik

  - name: wg-easy
    namespace: wg-easy
    needs:
      - traefik/traefik
```

The `needs:` field establishes a dependency graph: cert-manager installs first, then its issuers, then traefik, then the SDK (if enabled), then wg-easy. This is the helmfile equivalent of the `weight` field in HelmChart CRs.

### Two Invocations, Same Helmfile

```bash
# Local development -- charts from disk, no SDK, no image proxy
task helm-install

# Customer-like installation -- charts from OCI registry, SDK enabled, image proxy
task helm-install HELM_ENV=replicated
```

Same dependency ordering, same chart configuration, different sources and image paths.

## Release Assembly: task release-prepare

The [Taskfile.yaml `release-prepare` task](https://github.com/replicatedhq/platform-examples/blob/main/applications/wg-easy/Taskfile.yaml) assembles a complete release directory from the per-chart artifacts. Here is what each step does:

### Step 1: Copy HelmChart CRs and Replicated Manifests

```bash
find . -path './charts/*/replicated/*.yaml' -exec cp {} ./release/ \;
find ./replicated -name '*.yaml' -not -name 'config.yaml' -exec cp {} ./release/ \;
```

All `helmChart-*.yaml` files from each chart's `replicated/` directory, plus `application.yaml` and `cluster.yaml` from the root `replicated/` directory, are copied into `release/`.

### Step 2: Extract Namespaces into application.yaml

```bash
yq ea '[.spec.namespace] | unique' ./charts/*/replicated/helmChart-*.yaml \
  | yq '.spec.additionalNamespaces *= load("/dev/stdin") | .spec.additionalNamespaces += "*" ' \
    replicated/application.yaml > release/application.yaml
```

Reads the `spec.namespace` from every HelmChart CR, deduplicates them, and merges them into `application.yaml`'s `additionalNamespaces` field. This ensures KOTS creates all required namespaces.

### Step 3: Set Chart Versions

```bash
find ./charts -maxdepth 2 -mindepth 2 -type d -name replicated | while read chartDir; do
  parent=$(basename $(dirname $chartDir))
  helmChartName="helmChart-$parent.yaml"
  export version=$(yq -r '.version' $chartDir/../Chart.yaml)
  yq '.spec.chart.chartVersion = strenv(version)' $chartDir/$helmChartName \
    | tee release/$helmChartName
done
```

For each chart with a `replicated/` directory, reads the version from `Chart.yaml` and writes it into the corresponding `helmChart-*.yaml` in `release/`. This keeps HelmChart CR versions in sync with the actual chart versions.

### Step 4: Merge Config Files

```bash
echo "{}" > ./release/config.yaml

for config_file in $(find . -path '*/replicated/config.yaml' | grep -v "^./replicated/"); do
  yq eval-all '. as $item ireduce ({}; . * $item)' \
    ./release/config.yaml "$config_file" > ./release/config.yaml.new
  mv ./release/config.yaml.new ./release/config.yaml
done

# Merge root config.yaml last (takes precedence)
if [ -f "./replicated/config.yaml" ]; then
  yq eval-all '. as $item ireduce ({}; . * $item)' \
    ./release/config.yaml "./replicated/config.yaml" > ./release/config.yaml.new
  mv ./release/config.yaml.new ./release/config.yaml
fi
```

Starts with an empty config, iterates over each chart's `replicated/config.yaml`, and deep-merges them using `yq`. The root `replicated/config.yaml` is merged last so it can override per-chart settings if needed.

### Step 5: Package Charts

```bash
for chart_dir in $(find charts/ -maxdepth 2 -name "Chart.yaml" \
  | grep -v "charts/templates" | xargs dirname); do
  (cd "$chart_dir" && helm package . && mv *.tgz ../../release/)
done
```

Every chart except the `templates` library chart is packaged into a `.tgz` archive in `release/`. The templates chart is excluded because it is a dependency consumed at chart build time, not a standalone release artifact.

### The Final release/ Directory

After `task release-prepare`, the `release/` directory contains everything needed for `replicated release create --yaml-dir ./release`:

```
release/
  application.yaml              # Application metadata with merged additionalNamespaces
  cluster.yaml                  # Embedded cluster configuration
  config.yaml                   # Merged config screen from all charts
  helmChart-cert-manager.yaml   # HelmChart CR with version set
  helmChart-wg-easy.yaml        # HelmChart CR with version set
  helmChart-traefik.yaml        # HelmChart CR with version set (if present)
  cert-manager-1.0.0.tgz        # Packaged chart
  wg-easy-1.0.0.tgz             # Packaged chart
  traefik-*.tgz                  # Packaged chart
  ...                            # Additional charts as needed
```

## Adding a New Chart

To add a hypothetical `redis` chart to this application:

1. **Create the chart directory** with `Chart.yaml` wrapping the upstream Bitnami redis chart and depending on the shared `templates` chart:

    ```
    charts/redis/
      Chart.yaml
      values.yaml
    ```

2. **Add per-chart Replicated artifacts**:

    ```
    charts/redis/replicated/
      config.yaml              # Redis-specific config items (port, password, memory limit)
      helmChart-redis.yaml     # HelmChart CR with weight, namespace, image rewrites
    ```

3. **Add support bundle and preflight templates** (optional):

    ```
    charts/redis/templates/
      _supportbundle.tpl       # Collect redis logs, check memory settings
      secret-supportbundle.yaml
      _preflight.tpl           # Check minimum memory available
      secret-preflights.yaml
    ```

4. **Add the release to `helmfile.yaml.gotmpl`** with source entries in both environments and a `needs:` dependency:

    ```yaml
    - name: redis
      namespace: redis
      chart: {{ .Values.chartSources.redis }}
      version: {{ .Values.chartVersions.redis }}
      needs:
        - cert-manager/cert-manager-issuers
    ```

5. **Run `task release-prepare`**. The redis config items are merged into the unified config screen, the chart is packaged, and the HelmChart CR gets its version set. No other files need editing.

## Data Flow Diagram

```
charts/
  wg-easy/
    Chart.yaml  ──────────────────────┐
    replicated/                       │
      config.yaml  ───────────┐       │
      helmChart-wg-easy.yaml ─┼───┐   │
    templates/                │   │   │
      _supportbundle.tpl      │   │   │  (deployed via helm)
      secret-supportbundle.yaml   │   │
                              │   │   │
  cert-manager/               │   │   │
    Chart.yaml  ──────────────┤   │   │
    replicated/               │   │   │
      config.yaml  ───────────┤   │   │
      helmChart-cert-manager.yaml─┤   │
                              │   │   │
  templates/                  │   │   │  (dependency only, not packaged)
                              │   │   │
                              v   v   v
                     task release-prepare
                              │
                              v
                          release/
                            config.yaml          (merged from all charts)
                            application.yaml     (namespaces extracted)
                            helmChart-*.yaml     (versions set)
                            *.tgz                (packaged charts)
                              │
              ┌───────────────┼───────────────┐
              v               v               v
     replicated release   helmfile -e      helmfile
     create --yaml-dir    replicated       (default)
        ./release         apply            apply
              │               │               │
              v               v               v
         KOTS / EC        OCI registry     Local charts
         install          + image proxy    from disk
```
