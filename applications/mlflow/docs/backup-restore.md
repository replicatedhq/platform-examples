# MLflow Backup and Restore

This document describes the backup and restore procedures for MLflow deployed via KOTS with embedded PostgreSQL (CloudnativePG) and MinIO object storage.

## How KOTS Snapshots Work

KOTS uses [Velero](https://velero.io/) to create point-in-time snapshots of the application. When `allowSnapshots` is enabled in the Application manifest, the KOTS Admin Console exposes backup and restore controls under the **Snapshots** tab.

A KOTS snapshot captures:

- All Kubernetes resources in the application namespace (Deployments, Services, Secrets, ConfigMaps, CRDs, etc.)
- Persistent Volume Claims (PVCs) and their data via Velero's volume snapshot or file-system backup plugins

### Stateful Volumes

MLflow has two categories of stateful PVCs that contain critical data:

| Component | Managed By | PVC Pattern | Data |
|-----------|-----------|-------------|------|
| PostgreSQL | CloudnativePG Operator | `<release>-postgres-<instance>` | MLflow experiment metadata, run parameters, metrics |
| MinIO | MinIO Operator | `data-minio-pool-0-<index>` | MLflow model artifacts, datasets, logged files |

Both operators dynamically provision PVCs. Velero includes all PVCs in the application namespace by default when taking a KOTS snapshot.

## Prerequisites

- Velero installed with a compatible storage provider (AWS S3, GCP, Azure, or MinIO as a backup target)
- A configured Velero `BackupStorageLocation` pointing to an external object store (do **not** use the in-cluster MinIO as the backup target)
- The KOTS Admin Console preflight check for Velero should pass before taking backups

## Full Backup Procedure

### Via KOTS Admin Console

1. Open the Admin Console and navigate to **Snapshots** > **Full Snapshots**
2. Click **Start a snapshot**
3. Wait for the snapshot to reach **Completed** status
4. Verify the snapshot shows the expected PVC count (PostgreSQL + MinIO volumes)

### Via KOTS CLI

```bash
# Create a full snapshot (application + admin console)
kubectl kots backup --namespace <app-namespace>

# List existing backups
kubectl kots backup ls --namespace <app-namespace>
```

## Restore Procedure

Restoring MLflow requires attention to operator ordering. The CloudnativePG and MinIO operators must be running before their managed resources (Cluster CRs, Tenant CRs) are restored, or the restored custom resources will have no controller to reconcile them.

### Restore Steps

1. **Ensure operators are installed first.** If restoring to a fresh cluster (disaster recovery), install Embedded Cluster or deploy the infrastructure chart (`infra`) before restoring the application. The infra chart installs the CloudnativePG and MinIO operators.

2. **Initiate the restore** from the KOTS Admin Console or CLI:

   ```bash
   # List available backups
   kubectl kots backup ls --namespace <app-namespace>

   # Restore from a specific backup
   kubectl kots restore --from-backup <backup-name> --namespace <app-namespace>
   ```

3. **Wait for operators to reconcile.** After restore completes:
   - The CloudnativePG operator detects the restored `Cluster` CR and reconciles the PostgreSQL instances against the restored PVC data
   - The MinIO operator detects the restored `Tenant` CR and reconciles the MinIO pool against the restored PVC data

4. **Monitor pod readiness:**

   ```bash
   # Check PostgreSQL cluster status
   kubectl get clusters.postgresql.cnpg.io -n <app-namespace>
   kubectl get pods -l cnpg.io/cluster -n <app-namespace>

   # Check MinIO tenant status
   kubectl get tenants.minio.min.io -n <app-namespace>
   kubectl get pods -l v1.min.io/tenant -n <app-namespace>

   # Check MLflow deployment
   kubectl get deployment mlflow -n <app-namespace>
   ```

### Operator Ordering Considerations

| Scenario | Operator State | Action Required |
|----------|---------------|----------------|
| Restore to existing cluster | Operators already running | No special action; restore proceeds normally |
| Restore to fresh EC install | Operators installed by EC | Ensure EC install completes before restore |
| Restore to fresh KOTS install | Operators in infra chart | Ensure infra chart (weight: -10) deploys first |

If operators are not present when CRs are restored, the CRs will exist but remain unreconciled. In this case, reinstall the infra chart and the operators will pick up the existing CRs.

## Verification Steps Post-Restore

Run these checks after a restore to confirm data integrity:

### 1. PostgreSQL Connectivity

```bash
# Verify the CNPG cluster reports as healthy
kubectl get clusters.postgresql.cnpg.io -n <app-namespace> -o jsonpath='{.items[0].status.phase}'
# Expected: "Cluster in healthy state"

# Connect and verify data
kubectl exec -it <postgres-pod> -n <app-namespace> -- psql -U mlflow -d mlflow -c "SELECT count(*) FROM experiments;"
```

### 2. MinIO Object Access

```bash
# Port-forward to MinIO
kubectl port-forward svc/minio -n <app-namespace> 9000:9000 &

# Verify bucket contents (requires mc CLI)
mc alias set local http://localhost:9000 <access-key> <secret-key>
mc ls local/mlflow/
```

### 3. MLflow Application Health

```bash
# Verify MLflow pod is running
kubectl get pods -l app.kubernetes.io/name=mlflow -n <app-namespace>

# Check MLflow can read experiments
kubectl port-forward svc/mlflow -n <app-namespace> 5000:5000 &
curl -s http://localhost:5000/api/2.0/mlflow/experiments/search | head -c 200
```

### 4. KOTS Admin Console Status

After restore, the Admin Console should show:
- Application status: **Ready**
- All status informers green (`deployment/mlflow`, `services/mlflow`)

## Limitations

- **External PostgreSQL / S3**: If using external database or object storage (not embedded), those services are outside the KOTS snapshot scope. Back them up independently using your provider's backup tooling.
- **Backup target**: Do not configure Velero to store backups in the same MinIO instance that is being backed up. Use an external storage location.
- **Concurrent writes during backup**: For maximum consistency, consider scaling down the MLflow deployment before taking a snapshot, though Velero's file-system backup is crash-consistent.
- **Large artifacts**: MinIO PVC backups can be large if significant model artifacts are stored. Ensure the Velero backup storage location has sufficient capacity.
