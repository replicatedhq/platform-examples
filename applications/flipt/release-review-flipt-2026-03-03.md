# Helm Chart Architecture Review: Flipt

**Date:** 2026-03-03 | **Reviewer:** CRE (Automated) | **Chart Version:** v1.0.33

---

## Summary

Flipt is an open-source feature flag and experimentation platform deployed as a Helm chart with PostgreSQL (via CloudNativePG) and Valkey (Redis-compatible cache) as dependencies. The chart is well-structured overall with proper dependency management, comprehensive preflight/support-bundle specs, and a functional KOTS integration. However, several critical issues around air-gap image pull secrets, broken PDB configuration, Deployment hook misuse, and missing embedded-cluster conditionals need to be addressed before production readiness.

**Status:** Needs Work

**Critical Issues:** 4 | **High Priority:** 7 | **Medium:** 8

---

## Replicated Platform Integration

### Required Components

| Component | Status | Issue |
| :---- | :---- | :---- |
| Replicated SDK | Present | v1.16.0 (locked), condition-gated via `replicated.enabled` |
| kind: HelmChart (v1beta2) | Present | Correct apiVersion kots.io/v1beta2 |
| Preflight Checks | Present | Good coverage: K8s version, CPU, memory, storage, CNPG CRD, distribution |
| Support Bundle | Present | Comprehensive: logs, pod status, PG/Valkey diagnostics, connectivity |
| Image Components (registry/repo/tag) | Present | Flipt image properly split; subchart images handled |
| ImagePullSecrets | Missing | No `ImagePullSecretName` in HelmChart CR; no `global.replicated.dockerconfigjson` support in chart |
| Backup Hooks (if stateful) | Missing | No Velero backup hooks for PostgreSQL PVCs |
| Embedded Cluster Config | Present | EC config with cert-manager and ingress-nginx extensions; uses `kind: Config` (wrong kind) |

**Air-gap Ready:** No - Missing ImagePullSecretName injection for all pod specs including Jobs

---

## Critical Antipatterns

### Arrays as Top-Level Keys

**Found in:** None. Values use maps throughout -- this is clean.

### Blocked Dependencies

- **Bitnami Charts:** None found. Using CloudNativePG and upstream Valkey -- correct approach.
- **Cloud-Specific:** None. No cloud-provider-specific dependencies detected.

### Template Issues

- **`common.*` template name collisions** -- `_helpers.tpl` defines `common.tplvalues.render`, `common.storage.class`, `common.classes.podAnnotations`, and `common.classes.deploymentAnnotations`. The `common` prefix is generic and will collide with any other chart that defines `common.*` templates (e.g., Bitnami common chart, bjw-s common-template). These should be prefixed with `flipt.` instead.

- **Broken checksum annotation** -- `common.classes.podAnnotations` and `common.classes.deploymentAnnotations` reference `.Values.flipt` which does not exist in the values schema. This will produce a nil checksum that never changes, defeating the purpose of config-change-triggered rollouts.

- **Multiple YAML documents per file** -- `postgresql-cluster-job.yaml` contains 9 separate YAML documents (ServiceAccount, Role, RoleBinding, ConfigMap, Job x2, plus delete hooks). This should be split into separate files for maintainability.

- **Deployment used as Helm hook** -- The main Deployment has `helm.sh/hook: post-install,post-upgrade` applied conditionally when `postgresql.type == "embedded"`. This means the Deployment is created as a hook resource rather than a managed Helm resource, which causes issues with `helm status`, `helm upgrade` tracking, and resource ownership.

### KOTS Templating Issues

- **YAML quoting**: Generally correct; single quotes used appropriately around `repl{{ }}` expressions containing inner double quotes.
- **Boolean comparisons**: Correct -- uses `ConfigOptionEquals "field" "1"` pattern throughout.
- **optionalValues merge**: **PROBLEM** -- Multiple `optionalValues` entries use `recursiveMerge: false` (ingress with/without TLS, external PostgreSQL). This will cause shallow merge behavior that overwrites nested keys.
- **builder key**: Present with static values. Covers Flipt, CNPG, PostgreSQL, alpine/k8s, Valkey, and Replicated SDK images.

---

## Findings

### Critical (Fix Before Production)

**[C1] Missing ImagePullSecrets / air-gap image pull support** - `chart/templates/deployment.yaml`, `chart/templates/postgresql-cluster-job.yaml`, `replicated/kots-helm-chart.yaml`

The HelmChart CR does not inject `ImagePullSecretName` into the chart's `imagePullSecrets` value. The database Job pods also lack `imagePullSecrets` support. In air-gap environments with a local registry, pods will fail to pull images because they have no credentials.

```yaml
# Current: No ImagePullSecretName in HelmChart CR values
# Fix: Add to HelmChart CR spec.values:
imagePullSecrets:
  - name: repl{{ ImagePullSecretName }}
```

The Job template in `postgresql-cluster-job.yaml` also needs `imagePullSecrets` support:

```yaml
# Current: No imagePullSecrets in Job spec
# Fix: Add to Job pod spec:
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 8 }}
{{- end }}
```

*Why:* Without image pull credentials, all pods fail with `ImagePullBackOff` in air-gap and private registry environments. *Impact:* Complete deployment failure in air-gap.

---

**[C2] Deployment marked as Helm hook breaks lifecycle management** - `chart/templates/deployment.yaml:11-14`

```yaml
# Current:
{{- if eq .Values.postgresql.type "embedded" }}
helm.sh/hook: post-install,post-upgrade
helm.sh/hook-weight: "10"
{{- end }}
```

When `postgresql.type` is `embedded` (the default), the entire Deployment becomes a Helm hook resource. Hook resources are managed outside Helm's normal release tracking. This means:
- `helm status` will not show the Deployment
- `helm upgrade` may create duplicate Deployments
- `helm rollback` will not roll back the Deployment
- The Deployment is not cleaned up by `helm uninstall` (hooks require separate `hook-delete-policy`)

```yaml
# Fix: Remove the hook annotations from the Deployment entirely.
# If the intent is to wait for the database Job to complete before
# creating the Deployment, use a proper init container or
# adjust hook weights so the Job runs before the Deployment is applied.
```

*Why:* Making the primary application Deployment a hook fundamentally breaks Helm lifecycle management. *Impact:* Unpredictable upgrade behavior, orphaned resources on uninstall.

---

**[C3] PodDisruptionBudget references wrong values key** - `chart/templates/pdb.yaml:1`, `chart/values.yaml:164`

```yaml
# pdb.yaml reads:
{{- if (.Values.pdb).enabled }}

# values.yaml defines:
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

The template reads `.Values.pdb.enabled` but values defines `podDisruptionBudget.enabled`. The PDB is never created despite being enabled in values. Additionally, the template uses `maxUnavailable` but values defines `minAvailable`.

```yaml
# Fix option 1: Rename values key to match template
pdb:
  enabled: true
  maxUnavailable: "25%"

# Fix option 2: Update template to match values
{{- if .Values.podDisruptionBudget.enabled }}
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
```

*Why:* PDB is silently broken -- never deployed despite being "enabled" in values. *Impact:* No pod disruption protection; pods can all be evicted simultaneously during node drain or cluster upgrades.

---

**[C4] EmbeddedClusterConfig uses wrong `kind`** - `replicated/ec-cluster.yaml:2`

```yaml
# Current:
apiVersion: embeddedcluster.replicated.com/v1beta1
kind: Config

# Fix:
apiVersion: embeddedcluster.replicated.com/v1beta1
kind: EmbeddedClusterConfig
```

The file uses `kind: Config` which is the KOTS Config kind, not the Embedded Cluster kind. The Replicated release processing may not recognize this as an EC configuration.

*Why:* EC configuration may not be applied at all. *Impact:* Extensions (cert-manager, ingress-nginx) may not be installed on EC; unsupported overrides may not take effect.

---

### High Priority (Fix Before GA)

**[H1] optionalValues entries missing `recursiveMerge: true`** - `replicated/kots-helm-chart.yaml:172-215`

Three `optionalValues` entries use `recursiveMerge: false`:
1. Ingress without TLS (line 173)
2. Ingress with TLS (line 186)
3. External PostgreSQL (line 205)

Without `recursiveMerge: true`, these entries perform shallow merges. For example, the external PostgreSQL block sets `postgresql.external.*` values, but the shallow merge will replace the entire `postgresql` key, losing `postgresql.type`, `postgresql.database`, and `postgresql.username` from the base values.

```yaml
# Current:
- when: 'repl{{ ConfigOptionEquals "postgres_type" "external" }}'
  recursiveMerge: false
  values:
    postgresql:
      external:
        enabled: true
        ...

# Fix: Change to recursiveMerge: true on ALL optionalValues entries
- when: 'repl{{ ConfigOptionEquals "postgres_type" "external" }}'
  recursiveMerge: true
  values:
    postgresql:
      external:
        enabled: true
        ...
```

*Why:* Shallow merge overwrites sibling keys under the same parent, causing values like `postgresql.type` and `postgresql.database` to be lost.

---

**[H2] ConfigMap uses Helm hooks -- will be deleted on upgrade** - `chart/templates/flipt-config.yaml:7-8`

```yaml
# Current:
annotations:
  "helm.sh/hook": pre-install,pre-upgrade
  "helm.sh/hook-weight": "-1"
```

The ConfigMap is marked as a pre-install/pre-upgrade hook. Combined with the Deployment being a post-install/post-upgrade hook, this creates a fragile sequencing dependency through hooks rather than normal Helm resource management. If the ConfigMap hook does not have `hook-delete-policy: before-hook-creation`, old ConfigMaps accumulate. If it does get deleted, there is a window where the Deployment references a missing ConfigMap.

```yaml
# Fix: Remove hook annotations from ConfigMap.
# Helm manages ConfigMaps as regular resources and applies them
# before Deployments by default due to resource ordering.
```

*Why:* Hook-based resource management adds unnecessary complexity and fragility.

---

**[H3] No ingress configuration hiding on Embedded Cluster** - `replicated/kots-config.yaml:26-85`

The ingress configuration group is always visible, even on Embedded Cluster where ingress-nginx is built-in. EC users should not need to configure ingress class, TLS, or cert-manager settings because these are managed by the EC extensions.

```yaml
# Fix: Add Distribution guard to ingress items
- name: ingress_class
  title: Ingress Class
  type: select_one
  default: nginx
  when: 'repl{{ and (ne Distribution "embedded-cluster") (ConfigOptionEquals "ingress_enabled" "1") }}'
  ...

# Also set EC-specific defaults in HelmChart CR:
ingress:
  className: repl{{ eq Distribution "embedded-cluster" | ternary "nginx" (ConfigOption "ingress_class") }}
```

*Why:* Clutters the Admin Console with settings that EC manages automatically; user misconfiguration can break the built-in ingress.

---

**[H4] ClusterIssuer hardcodes `ingressClassName: nginx`** - `replicated/kots-cluster-issuer.yaml:16`

```yaml
# Current:
solvers:
  - http01:
      ingress:
        ingressClassName: nginx

# Fix: Make configurable or use the selected ingress class
solvers:
  - http01:
      ingress:
        ingressClassName: 'repl{{ if ConfigOptionEquals "ingress_class" "custom" }}repl{{ ConfigOption "ingress_class_custom" }}repl{{ else }}repl{{ ConfigOption "ingress_class" }}repl{{ end }}'
```

*Why:* Breaks TLS certificate issuance for users with Traefik or other ingress controllers.

---

**[H5] Broken checksum annotations reference non-existent `.Values.flipt`** - `chart/templates/_helpers.tpl:156,166`

```yaml
# Current:
{{- printf "checksum/config: %v" (join "," .Values.flipt | sha256sum) | nindent 0 -}}

# Fix: Reference the actual config values path
{{- printf "checksum/config: %v" (include (print $.Template.BasePath "/flipt-config.yaml") $ | sha256sum) | nindent 0 -}}
```

Note: The Deployment already has a correct checksum annotation on line 7. These helper functions are producing a static nil-derived checksum that adds no value. Either fix them to reference the correct values path, or remove the duplicate checksum from the helpers.

*Why:* Pods are not restarted when configuration changes because the checksum never changes.

---

**[H6] `common.*` template names will collide with other charts** - `chart/templates/_helpers.tpl:121-167`

Four templates use the generic `common.` prefix:
- `common.tplvalues.render`
- `common.storage.class`
- `common.classes.podAnnotations`
- `common.classes.deploymentAnnotations`

```yaml
# Fix: Rename to flipt-prefixed templates
{{- define "flipt.tplvalues.render" -}}
{{- define "flipt.storage.class" -}}
{{- define "flipt.classes.podAnnotations" -}}
{{- define "flipt.classes.deploymentAnnotations" -}}
```

*Why:* Helm has a flat template namespace. If any subchart or parent chart defines `common.tplvalues.render`, the last-loaded definition wins, causing silent rendering corruption.

---

**[H7] Multiple YAML documents in postgresql-cluster-job.yaml** - `chart/templates/postgresql-cluster-job.yaml`

This single file contains 9 YAML documents across ~292 lines: ServiceAccount, Role, RoleBinding, ConfigMap, Job (for create), and another ServiceAccount, Role, RoleBinding, Job (for delete). This violates the one-resource-per-file best practice.

```
# Fix: Split into separate files:
# templates/postgresql-create-sa.yaml
# templates/postgresql-create-rbac.yaml
# templates/postgresql-create-manifest.yaml
# templates/postgresql-create-job.yaml
# templates/postgresql-delete-sa.yaml
# templates/postgresql-delete-rbac.yaml
# templates/postgresql-delete-job.yaml
```

*Why:* Difficult to review, debug, and maintain. Helm error messages reference file + line, which is confusing with multi-document files.

---

### Medium Priority (Recommended)

**[M1] Job containers missing resource requests/limits** - `chart/templates/postgresql-cluster-job.yaml:145-191,271-291`

Both the create-db and delete-db Job containers have no `resources:` block. Clusters with resource quotas will reject these pods.

```yaml
# Fix: Add resources to values.yaml
dbJob:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi
```

---

**[M2] Job containers missing securityContext** - `chart/templates/postgresql-cluster-job.yaml:145,271`

The Job pods run without explicit security context, defaulting to potentially root execution. This will fail on OpenShift and clusters enforcing restricted Pod Security Standards.

---

**[M3] Preflight collectors reference `.Values.namespace` which does not exist** - `chart/templates/_preflight.tpl:147,155`

```yaml
# Current:
namespace: {{ .Values.namespace | default "flipt" | quote }}

# Fix: Use .Release.Namespace
namespace: "{{ .Release.Namespace }}"
```

*Why:* The `namespace` value is not defined in `values.yaml`, so the preflight collector always targets the `flipt` namespace, which may not be correct.

---

**[M4] Preflight exec collector runs `kubectl version` inside application pod** - `chart/templates/_preflight.tpl:151-158`

The exec collector attempts to run `kubectl` inside a Flipt pod. The Flipt container image likely does not include `kubectl`. This collector will always fail.

---

**[M5] Support bundle exec collectors assume `helm`, `nc`, and `psql` are available in pods** - `chart/templates/_supportbundle.tpl:153-190`

Several collectors attempt to run `helm get values`, `helm get manifest`, `nc -zv`, and `psql` inside application and database pods. These tools may not be present in the container images (especially with `readOnlyRootFilesystem: true` preventing runtime installation).

---

**[M6] Valkey subchart image missing `registry` field split** - `chart/values.yaml:260`

```yaml
# Current:
valkey:
  image:
    repository: ghcr.io/valkey-io/valkey
    tag: "8.0"

# The registry is embedded in repository. If the Valkey subchart supports
# a separate registry field, split it for cleaner air-gap rewriting.
```

---

**[M7] HTTPS port on Deployment container references service port, not container port** - `chart/templates/deployment.yaml:65-66`

```yaml
# Current:
- name: https
  containerPort: {{ .Values.service.httpsPort }}

# This maps to port 443, but Flipt likely doesn't listen on 443 inside the container.
# If Flipt doesn't serve HTTPS natively, this port is unused and misleading.
```

---

**[M8] `podSecurityContext` hardcodes `runAsUser: 100` and `runAsGroup: 1000`** - `chart/values.yaml:42-43`

Hardcoding UID/GID values will fail on OpenShift, where the restricted SCC allocates UIDs from a namespace-specific range. The `securityContext` at line 56 also hardcodes `runAsUser: 100`.

```yaml
# Fix: Remove explicit runAsUser/runAsGroup from defaults
# (keep runAsNonRoot: true, which works across distributions)
podSecurityContext:
  runAsNonRoot: true
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  seccompProfile:
    type: "RuntimeDefault"
```

---

## Replicated Release Integration

### HelmChart CR Assessment

| Check | Status | Notes |
| :---- | :---- | :---- |
| apiVersion: kots.io/v1beta2 | Present | Correct |
| Template function syntax correct | Present | Proper use of `repl{{ }}` for values, `{{repl }}` for control flow in `when` |
| optionalValues use recursiveMerge | Issue | 3 of 5 entries use `recursiveMerge: false` -- will cause shallow merge data loss |
| Air-gap image rewriting | Partial | Image rewriting patterns present for all images; missing `ImagePullSecretName` injection |
| builder key covers all images | Present | All 6 images covered: Flipt, CNPG operator, PostgreSQL, alpine/k8s, Valkey, Replicated SDK |
| exclude field logic correct | Present | `exclude: ""` (never excluded) |

### Config CR Assessment

| Check | Status | Notes |
| :---- | :---- | :---- |
| Boolean fields use type: bool | Present | All booleans use `type: bool` with `"0"`/`"1"` defaults |
| Required fields have defaults | Present | All fields have sensible defaults |
| Conditional when clauses correct | Present | Proper `when` guards on dependent fields; correct syntax with single quotes |
| Hidden generated secrets use value: not default: | N/A | No generated secrets in Config (passwords handled differently) |
| EC Distribution conditionals | Missing | No `ne Distribution "embedded-cluster"` guards on ingress configuration |

---

## Action Items

### Must Fix

1. [C1] Add ImagePullSecretName injection for air-gap support - medium effort
2. [C2] Remove Helm hook annotations from Deployment - small effort
3. [C3] Fix PDB values key mismatch (`pdb` vs `podDisruptionBudget`) - small effort
4. [C4] Fix EmbeddedClusterConfig kind from `Config` to `EmbeddedClusterConfig` - small effort
5. [H1] Add `recursiveMerge: true` to all optionalValues entries - small effort
6. [H2] Remove Helm hook annotations from ConfigMap - small effort

### Should Fix (Before GA)

1. [H3] Add `ne Distribution "embedded-cluster"` guards to ingress config - medium effort
2. [H4] Make ClusterIssuer ingressClassName configurable - small effort
3. [H5] Fix broken checksum annotation helpers referencing `.Values.flipt` - small effort
4. [H6] Rename `common.*` templates to `flipt.*` - small effort
5. [H7] Split postgresql-cluster-job.yaml into separate files - medium effort
6. [M1] Add resource requests/limits to Job containers - small effort
7. [M2] Add securityContext to Job containers - small effort
8. [M3] Fix preflight namespace reference to use `.Release.Namespace` - small effort

### Optional Improvements

1. [M4] Remove or fix preflight `kubectl version` exec collector
2. [M5] Review support bundle exec collectors for tool availability
3. [M6] Split Valkey image registry field if subchart supports it
4. [M7] Remove or fix unused HTTPS containerPort
5. [M8] Remove hardcoded `runAsUser`/`runAsGroup` for OpenShift compatibility

---

## Next Steps

1. **Vendor Fixes** - Target: 2026-03-17 (critical items)
2. **Follow-up Review** - Target: 2026-03-24
3. **Testing** - Air-gap install test on EC, existing cluster test on k3s/EKS
4. **Production Ready** - Target: 2026-04-07

---

## Notes

**Contacts:** Replicated (chart maintainer) **Installation Target:** EC + Helm CLI **Environment:** Multi-distribution (EC, EKS, GKE, AKS, k3s)

### Additional Observations

1. **Chart.yaml is missing `icon` field** -- `helm lint` reported this as INFO. Add an icon URL for better Helm repository presentation.

2. **Status informers may be incorrect** -- `kots-app.yaml` references `deployment/flipt` (the name depends on the release name), `deployment/flipt-cloudnative-pg`, and `deployment/flipt-valkey`. If the release name is not `flipt`, these informers will not match. The lint config explicitly disables the `nonexistent-status-informer-object` check, which suggests this is a known issue. Consider using `{{repl }}` templating in status informers to reference the actual release name.

3. **Valkey subchart workaround** -- A custom `valkey-service.yaml` works around a bug in the Valkey chart v0.2.0 service targeting. This should be documented and tracked for removal when the upstream chart is fixed.

4. **No backup/restore hooks** -- PostgreSQL data is stateful but there are no Velero backup hooks or CNPG backup configuration enabled by default. For production deployments, backup strategy should be documented and optionally enabled.

5. **The `LicenseFieldValue "isSnapshotSupported"` optionalValues entry** (line 218) uses `LicenseFieldValue` without `ParseBool`. Since `LicenseFieldValue` returns strings, this will render the string `"true"` or `"false"` rather than a YAML boolean. However, in a `when` context for optionalValues, the string `"true"` will be truthy, so this likely works in practice. For correctness, consider adding `| ParseBool`.
