# MLflow Auto-Update Behavior

This document describes how KOTS automatic updates work with MLflow's multi-chart HelmChart weight ordering, including edge cases and recommended settings.

## How Auto-Deploy Works

KOTS can automatically deploy new releases based on semantic versioning. The `semverAutoDeploy` field in the Application manifest controls this behavior:

| Value | Behavior |
|-------|----------|
| `disabled` | No automatic deployment (manual deploy only) |
| `auto-patch` | Automatically deploy patch updates (e.g., 1.0.1 → 1.0.2) |
| `auto-minor-patch` | Automatically deploy minor and patch updates (e.g., 1.0.x → 1.1.x) |
| `auto-major-minor-patch` | Automatically deploy all semver updates |

This application uses `auto-patch` as a balanced default: critical fixes deploy automatically while feature releases require manual review.

## Multi-Chart Weight Ordering

MLflow uses two HelmChart resources with different weights to control installation and upgrade order:

| Chart | Weight | Purpose |
|-------|--------|---------|
| `infra` | -10 | Infrastructure operators (CloudnativePG, MinIO Operator) |
| `mlflow` | 10 | Application chart (MLflow server, database clusters, MinIO tenants) |

KOTS deploys charts in ascending weight order. Lower weights deploy first. This ordering is critical because:

1. **Install**: The infra chart installs CRD-providing operators (CloudnativePG, MinIO Operator) before the mlflow chart creates custom resources that depend on those CRDs.
2. **Upgrade**: Operator upgrades (new CRD versions, controller changes) complete before application resources are reconciled against the updated operators.

When `semverAutoDeploy` triggers an automatic update, KOTS respects this weight ordering. The infra chart upgrades first (`--wait --timeout 600s`), and only after it succeeds does the mlflow chart upgrade begin.

## Edge Cases

### CRD Changes During Operator Upgrades

When a new release updates a CRD-providing operator (e.g., CloudnativePG), the infra chart upgrade installs updated CRDs before the mlflow chart reconciles. Helm's `--wait` flag on the infra chart ensures the operator pod is running and ready before proceeding. However, if the operator needs time to migrate existing custom resources to a new CRD version, the 600-second timeout may not be sufficient for large clusters.

**Mitigation**: For clusters with many PostgreSQL clusters or MinIO tenants, consider increasing the `--timeout` value in `infra-chart.yaml` or using `disabled` auto-deploy to control upgrade timing.

### Config Field Changes Requiring Re-Deploy

Some KOTS config changes (e.g., switching from embedded to external PostgreSQL) alter which charts are deployed via HelmChart `exclude` conditions. Auto-deploy only triggers on new release versions, not config changes. When a config change requires re-deploy:

1. The admin saves new config values in the KOTS Admin Console
2. KOTS generates a new version from the config change
3. The admin must manually deploy this version, even with auto-deploy enabled

Auto-deploy does not apply to config-triggered versions — only to upstream releases from the vendor.

### Semver Rollback Behavior

KOTS does not automatically deploy versions older than the currently deployed version, even if the channel sequence is higher. For example, if version 1.2.0 is deployed and the vendor publishes 1.1.5 (a backport), auto-deploy skips it because 1.1.5 < 1.2.0 in semver ordering.

To deploy an older version, `allowRollback` must be enabled and the rollback must be triggered manually from the Admin Console.

### Required Versions

If a release is marked as `isRequired` by the vendor, KOTS will not skip it during auto-deploy. Required versions are always deployed in sequence before any later version. This means a required release that introduces a breaking migration will be applied even if a newer patch is also available.

### Conditional Chart Exclusion

The infra chart has an `exclude` condition that skips it when external PostgreSQL is configured. When auto-deploy triggers an update in this configuration:

- Only the mlflow chart deploys (weight ordering is irrelevant with a single chart)
- The operator CRDs remain at their last-installed version
- Ensure external database compatibility is validated before enabling auto-deploy in this configuration

## Recommended Settings

### Production Channels

```yaml
semverAutoDeploy: auto-patch
```

Patch-only auto-deploy is recommended for production. This ensures critical bug fixes and security patches are applied automatically while feature releases (minor/major) require explicit review and testing.

### Development / Staging Channels

```yaml
semverAutoDeploy: auto-minor-patch
```

Development and staging environments benefit from more aggressive auto-deploy to catch integration issues early. Minor version bumps often introduce new features that need validation before reaching production.

### Air-Gap Environments

Auto-deploy has no effect in air-gap environments. New releases must be manually uploaded to the Admin Console as airgap bundles. The `semverAutoDeploy` field is ignored when the instance cannot reach the update server.
