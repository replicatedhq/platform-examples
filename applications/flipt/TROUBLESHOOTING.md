# Flipt Troubleshooting Guide

Common issues and solutions for deploying Flipt.

## Installation Issues

### Error: "no matches for kind 'Cluster' in version 'postgresql.cnpg.io/v1'"

**Full error:**
```
Error: INSTALLATION FAILED: unable to build kubernetes objects from release manifest:
resource mapping not found for name: "flipt-cluster" namespace: "flipt" from "":
no matches for kind "Cluster" in version "postgresql.cnpg.io/v1"
ensure CRDs are installed first
```

**Cause:** The CloudNativePG operator is not installed in your cluster.

**Solution:** Install the operator before installing Flipt:

```bash
# Quick install
./scripts/install-cnpg-operator.sh

# Or manually
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
helm upgrade --install cnpg \
  --namespace cnpg-system \
  --create-namespace \
  cnpg/cloudnative-pg

# Verify operator is running
kubectl get pods -n cnpg-system
```

**Verify CRDs are installed:**
```bash
kubectl get crd | grep postgresql.cnpg.io

# Should show:
# backups.postgresql.cnpg.io
# clusters.postgresql.cnpg.io
# poolers.postgresql.cnpg.io
# scheduledbackups.postgresql.cnpg.io
```

---

### Error: "nil pointer evaluating interface {}.enabled"

**Full error:**
```
Error: INSTALLATION FAILED: flipt/templates/postgresql-cluster.yaml:65:32
  executing "flipt/templates/postgresql-cluster.yaml" at
  <.Values.postgresql.embedded.cluster.monitoring.enabled>:
    nil pointer evaluating interface {}.enabled
```

**Cause:** Missing field in values.yaml (should be fixed in the latest version).

**Solution:** Ensure you're using the latest chart or add to values.yaml:

```yaml
postgresql:
  embedded:
    cluster:
      monitoring:
        enabled: false
```

---

### Error: Dependencies not found

**Error:**
```
Error: found in Chart.yaml, but missing in charts/ directory: flipt, redis, replicated
```

**Solution:** Update Helm dependencies:

```bash
cd chart
helm dependency update
cd ..
```

Or use the Makefile:
```bash
make update-deps
```

---

### Error: CRD ownership conflict with CloudNativePG

**Full error:**
```
Error: INSTALLATION FAILED: unable to continue with install:
CustomResourceDefinition "backups.postgresql.cnpg.io" in namespace "" exists
and cannot be imported into the current release: invalid ownership metadata;
annotation validation error: key "meta.helm.sh/release-name" must equal "flipt":
current value is "cnpg"
```

**Cause:** Cached CloudNativePG dependency files from a previous configuration.

**Solution:** Clean and rebuild dependencies:

```bash
cd chart

# Remove cached operator dependency
rm -f charts/cloudnative-pg-*.tgz
rm -f Chart.lock

# Rebuild dependencies
helm dependency update
cd ..

# Now install
helm install flipt ./chart --namespace flipt --create-namespace
```

Or use the Makefile:
```bash
make clean
make update-deps
make install
```

**Note:** The CloudNativePG operator should be installed separately at the cluster level, not as a chart dependency.

---

### Error: Replicated SDK License Required

**Full error:**
```
Error: either license in the config file or integration license id must be specified
```

**Cause:** No Replicated license is configured.

**Solution:** Set up a development license:

```bash
# Quick setup
export REPLICATED_API_TOKEN=your-token
./scripts/setup-dev-license.sh
source .replicated/license.env
./scripts/install.sh
```

**Detailed guide:** See [docs/DEVELOPMENT_LICENSE.md](docs/DEVELOPMENT_LICENSE.md)

**For CI/CD:** Licenses can be created programmatically and cleaned up after tests.

---

### Pods Stuck in Pending State

**Symptoms:**
```bash
kubectl get pods -n flipt
# Shows pods in "Pending" state
```

**Common causes:**

1. **No storage class available:**
   ```bash
   kubectl get storageclass

   # If empty, you need a storage class
   # For local testing (minikube/kind):
   kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
   ```

2. **Insufficient resources:**
   ```bash
   kubectl describe pod <pod-name> -n flipt

   # Look for:
   # "0/3 nodes are available: 3 Insufficient cpu"
   # "0/3 nodes are available: 3 Insufficient memory"
   ```

   **Solution:** Reduce resource requests in values.yaml or add more nodes.

3. **PVC not binding:**
   ```bash
   kubectl get pvc -n flipt

   # If status is "Pending", check events:
   kubectl describe pvc <pvc-name> -n flipt
   ```

---

### PostgreSQL Cluster Not Starting

**Check cluster status:**
```bash
kubectl get cluster -n flipt

# Should show status "Cluster in healthy state"
```

**If unhealthy, check pod logs:**
```bash
kubectl logs -l cnpg.io/cluster=flipt-cluster -n flipt

# Common issues:
# - PVC not available
# - Insufficient permissions
# - Image pull errors
```

**Verify operator is running:**
```bash
kubectl get pods -n cnpg-system

# Should show:
# cnpg-cloudnative-pg-xxx   1/1   Running
```

---

### Redis Connection Issues

**Check Redis status:**
```bash
kubectl get pods -l app.kubernetes.io/name=redis -n flipt

# Should show master (and replica if configured) running
```

**Test Redis connectivity from Flipt pod:**
```bash
kubectl exec -it deploy/flipt-flipt -n flipt -- sh

# Inside pod:
nc -zv flipt-redis-master 6379
# Should show: Connection to flipt-redis-master 6379 port [tcp/*] succeeded!

# Test with redis-cli (if available):
redis-cli -h flipt-redis-master -p 6379 -a <password> ping
# Should return: PONG
```

**Check Redis password:**
```bash
kubectl get secret flipt-redis -n flipt -o jsonpath='{.data.redis-password}' | base64 -d
```

---

### Flipt UI Not Accessible

**Check service:**
```bash
kubectl get svc flipt-flipt -n flipt

# Should show:
# NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
# flipt-flipt   ClusterIP   10.96.xxx.xxx   <none>        8080/TCP,9000/TCP
```

**Test port-forward:**
```bash
kubectl port-forward -n flipt svc/flipt-flipt 8080:8080

# Open browser to http://localhost:8080
```

**If ingress is enabled, check ingress:**
```bash
kubectl get ingress -n flipt
kubectl describe ingress flipt-flipt -n flipt

# Common issues:
# - Ingress controller not installed
# - DNS not pointing to ingress
# - TLS certificate issues
```

---

### Ingress Issues

**No ingress controller:**
```bash
kubectl get ingressclass

# If empty, install one:
# For NGINX:
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

**TLS certificate issues:**
```bash
# Check certificate secret
kubectl get secret flipt-tls -n flipt

# If using cert-manager, check certificate:
kubectl get certificate -n flipt
kubectl describe certificate flipt-tls -n flipt

# Check cert-manager logs:
kubectl logs -n cert-manager -l app=cert-manager
```

---

## Alternative: Use External PostgreSQL

If you prefer not to use the CloudNativePG operator, use an external PostgreSQL database:

**values.yaml:**
```yaml
postgresql:
  type: external

  embedded:
    enabled: false

  external:
    enabled: true
    host: your-postgres-host.com
    port: 5432
    database: flipt
    username: flipt
    password: your-secure-password
    sslMode: require
```

**Or use Bitnami PostgreSQL (simpler, single instance):**

1. Modify Chart.yaml to use Bitnami PostgreSQL instead:
   ```yaml
   dependencies:
     - name: postgresql
       version: "12.x.x"
       repository: https://charts.bitnami.com/bitnami
       condition: postgresql.enabled
   ```

2. Adjust values.yaml accordingly.

---

## Alternative: Use External Redis

If you don't want embedded Redis:

**values.yaml:**
```yaml
redis:
  enabled: false

flipt:
  config:
    cache:
      enabled: false  # Disable caching
      # Or configure external Redis:
      # backend: redis
      # redis:
      #   url: redis://external-redis:6379
```

---

## Debugging Commands

### View all resources
```bash
kubectl get all -n flipt
```

### Check events
```bash
kubectl get events -n flipt --sort-by='.lastTimestamp'
```

### View logs
```bash
# Flipt logs
kubectl logs -l app.kubernetes.io/name=flipt -n flipt --tail=100 -f

# PostgreSQL logs
kubectl logs -l cnpg.io/cluster=flipt-cluster -n flipt --tail=100 -f

# Redis logs
kubectl logs -l app.kubernetes.io/name=redis -n flipt --tail=100 -f
```

### Check configuration
```bash
# View rendered values
helm get values flipt -n flipt

# View full manifest
helm get manifest flipt -n flipt

# Test template rendering locally
helm template flipt ./chart --debug
```

### Resource usage
```bash
# Check pod resource usage
kubectl top pods -n flipt

# Check node resource usage
kubectl top nodes
```

---

## Performance Issues

### Slow flag evaluations

**Enable Redis caching:**
Ensure Redis is enabled and Flipt is configured to use it:

```yaml
redis:
  enabled: true

flipt:
  config:
    cache:
      enabled: true
      backend: redis
      ttl: 5m
```

**Increase cache TTL:**
```yaml
flipt:
  config:
    cache:
      ttl: 10m  # Increase from 5m
```

**Scale Flipt horizontally:**
```yaml
flipt:
  replicaCount: 3  # More replicas
```

### Database performance

**Check connection pool settings:**
```yaml
flipt:
  config:
    db:
      maxIdleConn: 25
      maxOpenConn: 100
      connMaxLifetime: 1h
```

**Scale PostgreSQL:**
```yaml
postgresql:
  embedded:
    cluster:
      instances: 3  # HA cluster
      resources:
        limits:
          cpu: 2000m
          memory: 4Gi
```

---

## Uninstall Issues

### Complete uninstall
```bash
# Uninstall Flipt
helm uninstall flipt -n flipt

# Delete PVCs (data will be lost!)
kubectl delete pvc -l app.kubernetes.io/instance=flipt -n flipt

# Delete namespace
kubectl delete namespace flipt

# Optionally uninstall operator (if no other apps use it)
helm uninstall cnpg -n cnpg-system
kubectl delete namespace cnpg-system
```

### Stuck in terminating state
```bash
# Force delete namespace
kubectl delete namespace flipt --grace-period=0 --force

# Remove finalizers if needed
kubectl patch namespace flipt -p '{"metadata":{"finalizers":[]}}' --type=merge
```

---

## Getting Help

1. **Check logs:** Start with `kubectl logs` for the failing component
2. **Review events:** `kubectl get events -n flipt --sort-by='.lastTimestamp'`
3. **Generate support bundle:** `make support-bundle`
4. **Community:**
   - Flipt Discord: https://discord.gg/kRhEqG2T
   - Flipt GitHub Issues: https://github.com/flipt-io/flipt/issues
   - Replicated Support: https://support.replicated.com

---

## Useful Resources

- [Flipt Documentation](https://docs.flipt.io)
- [CloudNativePG Documentation](https://cloudnative-pg.io/)
- [Kubernetes Debugging Guide](https://kubernetes.io/docs/tasks/debug/)
- [Helm Troubleshooting](https://helm.sh/docs/faq/troubleshooting/)
