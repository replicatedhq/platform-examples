# Deploying MongoDB Operator with Replicated

This pattern demonstrates deploying the Percona MongoDB Operator using multiple Helm charts with KOTS orchestration. The operator chart installs Custom Resource Definitions (CRDs), and the database chart deploys a MongoDB replica set cluster. Proper weight configuration ensures the operator is ready before the database deploys.

## Architecture

- **Operator Chart** (`psmdb-operator`): Installs the Percona MongoDB Operator and CRDs
- **Database Chart** (`psmdb-db`): Deploys a MongoDB replica set cluster

## KOTS HelmChart Configuration

### Operator Chart

```yaml
apiVersion: kots.io/v1beta2
kind: HelmChart
metadata:
  name: psmdb-operator
spec:
  chart:
    name: psmdb-operator
    chartVersion: 1.17.0
    helmRepositories:
      - name: percona
        repository: https://percona.github.io/percona-helm-charts/
  weight: -10
  namespace: mongodb-system
  helmUpgradeFlags:
    - --create-namespace
    - --wait
    - --timeout
    - 300s
  values:
    watchAllNamespaces: false
    watchNamespace: "default"
```

The `weight: -10` ensures the operator installs before the database chart. The `--wait` flag ensures CRDs are registered before proceeding.

Note: Ensure that `spec.values.watchNamespace` matches the namespace where you deploy the database chart. If you change the database namespace from `default`, update `watchNamespace` accordingly so the operator reconciles your CRs.

### Database Chart

```yaml
apiVersion: kots.io/v1beta2
kind: HelmChart
metadata:
  name: psmdb-database
spec:
  chart:
    name: psmdb-db
    chartVersion: 1.17.0
    helmRepositories:
      - name: percona
        repository: https://percona.github.io/percona-helm-charts/
  weight: 10
  namespace: default
  helmUpgradeFlags:
    - --wait
    - --timeout
    - 600s
  values:
    crVersion: 1.17.0
    replsets:
      - name: rs0
        size: repl{{ ConfigOption "mongodb_replica_count" }}
        volumeSpec:
          persistentVolumeClaim:
            storageClassName: repl{{ ConfigOption "storage_class" }}
            resources:
              requests:
                storage: repl{{ ConfigOption "mongodb_storage_size" }}
        resources:
          limits:
            cpu: "2"
            memory: "4G"
          requests:
            cpu: "500m"
            memory: "1G"
  optionalValues:
    - when: 'repl{{ ConfigOptionEquals "enable_backups" "1" }}'
      recursiveMerge: true
      values:
        backup:
          enabled: true
          storages:
            s3-backup:
              type: s3
              s3:
                bucket: my-backup-bucket
                region: us-west-2
                credentialsSecret: mongodb-s3-credentials
          tasks:
            - name: daily-backup
              enabled: true
              schedule: "0 2 * * *"
              storageName: s3-backup
              compressionType: gzip
```

The `weight: 10` ensures this installs after the operator. The extended timeout (600s) allows time for database pods to initialize. Config values from the KOTS Config section are passed to the Helm chart using template functions.

## KOTS Config Options

Configure MongoDB settings via KOTS Config:

```yaml
apiVersion: kots.io/v1beta1
kind: Config
metadata:
  name: mongodb-config
spec:
  groups:
    - name: mongodb_settings
      title: MongoDB Configuration
      items:
        - name: mongodb_replica_count
          title: Replica Set Size
          type: text
          default: "3"

        - name: mongodb_storage_size
          title: Storage Size Per Replica
          type: text
          default: "20Gi"

        - name: storage_class
          title: Storage Class
          type: text
          default: "standard"

        - name: enable_backups
          title: Enable Automated Backups
          type: bool
          default: "0"
```

## Connection Secrets

The Percona MongoDB Operator automatically provisions Kubernetes secrets for database access:

### User Secrets

The operator creates a Kubernetes secret containing connection credentials for applications:
- Database admin credentials
- User credentials
- System user accounts

**For Helm deployments**, the secret name follows the pattern: `<release-name>-psmdb-db-secrets`

For example, if you install the `psmdb-db` chart with release name `my-mongodb`, the secret will be named `my-mongodb-psmdb-db-secrets`.

### Internal Secrets

The operator creates two key secret types:
- **Application credentials secret**: `<release-name>-psmdb-db-secrets` (primary secret your apps should consume)
- **Internal operator secret**: `internal-<release-name>-psmdb-db-users` (used by the operator; do not modify)

The internal secret mirrors the application secret and is used exclusively by the operator for internal operations.

**Documentation:**
- [Application and System Users](https://docs.percona.com/percona-operator-for-mongodb/users.html)
- [Connect to MongoDB](https://docs.percona.com/percona-operator-for-mongodb/connect.html)

### Accessing Connection Credentials

The application credentials secret contains keys for various system users. Key fields include:

- `MONGODB_DATABASE_ADMIN_USER` - Admin username (default: `databaseAdmin`)
- `MONGODB_DATABASE_ADMIN_PASSWORD` - Admin password
- Additional user credentials for backup, monitoring, and cluster operations

**Retrieving credentials:**

```bash
# Get the admin username
kubectl get secret <release-name>-psmdb-db-secrets -n default \
  -o jsonpath='{.data.MONGODB_DATABASE_ADMIN_USER}' | base64 -d

# Get the admin password
kubectl get secret <release-name>-psmdb-db-secrets -n default \
  -o jsonpath='{.data.MONGODB_DATABASE_ADMIN_PASSWORD}' | base64 -d
```

**Connection string format for replica sets:**

```
mongodb://<username>:<password>@<release-name>-rs0.<namespace>.svc.cluster.local/admin?replicaSet=rs0&ssl=false
```

**Using credentials in application deployments:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mongodb-client
spec:
  containers:
  - name: mongodb-client
    image: mongo:6.0
    env:
    - name: MONGODB_USER
      valueFrom:
        secretKeyRef:
          name: <release-name>-psmdb-db-secrets
          key: MONGODB_DATABASE_ADMIN_USER
    - name: MONGODB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: <release-name>-psmdb-db-secrets
          key: MONGODB_DATABASE_ADMIN_PASSWORD
```

See the [Percona connection documentation](https://docs.percona.com/percona-operator-for-mongodb/connect.html) for complete details on available secret keys and connection methods.

## Upgrading

- Keep `spec.chart.chartVersion` for `psmdb-operator` and the `crVersion` in the database chart values in lockstep (e.g., both `1.17.0`).
- Upgrade order matters due to CRDs and controller changes: apply operator upgrade first (lower weight), then the database chart (higher weight).
- Re-verify that `watchNamespace` is correct after namespace changes, and allow additional time for reconciliation during major upgrades.

## Additional Resources

- [Replicated HelmChart Reference](https://docs.replicated.com/reference/custom-resource-helmchart-v2)
- [Orchestrating Resource Deployment](https://docs.replicated.com/vendor/orchestrating-resource-deployment)
- [Percona MongoDB Operator Documentation](https://docs.percona.com/percona-operator-for-mongodb/)
- [Helm Hooks Documentation](https://helm.sh/docs/topics/charts_hooks/)
