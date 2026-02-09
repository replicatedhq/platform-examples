# Flipt Quick Start Guide

Get up and running with Flipt in 5 minutes.

## Prerequisites

- Kubernetes cluster (1.24+)
- Helm 3.8+
- kubectl configured

## ⚠️ Prerequisites

Before you begin, you need a **Replicated development license**:

```bash
# 1. Set your Replicated API token
export REPLICATED_API_TOKEN=your-token-here


**Don't have a Replicated account?**
- Sign up at [vendor.replicated.com](https://vendor.replicated.com)
- See [Development License Guide](docs/DEVELOPMENT_LICENSE.md) for detailed instructions

## Option 1: Quick Install (Development)

Install with default settings for testing:

### Easy Install (Recommended)

Use the automated installation script:

```bash
./scripts/install.sh
```

This script will:
- ✅ Check prerequisites (kubectl, helm)
- ✅ Install CloudNativePG operator (if not present)
- ✅ Add all required Helm repositories
- ✅ Clean and rebuild dependencies
- ✅ Install Flipt with all components
- ✅ Show status and next steps

### Manual Install

If you prefer to run commands manually:

```bash
# Step 1: Update chart dependencies (includes CloudNativePG operator)
cd chart
rm -f Chart.lock  # Clean cached files
helm repo add flipt https://helm.flipt.io
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo add replicated https://charts.replicated.com
helm repo update
helm dependency update
cd ..

# Step 2: Install Flipt (operator included automatically)
helm install flipt ./chart \
  --namespace flipt \
  --create-namespace \
  --wait \
  --timeout 10m

# Step 3: Port forward to access
kubectl port-forward -n flipt svc/flipt-flipt 8080:8080
```

Open your browser to: **http://localhost:8080**

## Option 2: Replicated KOTS Install

For enterprise deployments with admin console:

1. **Upload the application** to your Replicated vendor portal:
   ```bash
   replicated release create --auto --yaml-dir replicated/
   ```

2. **Install via Replicated Admin Console**:
   - Log into your Replicated admin console
   - Select the Flipt application
   - Follow the configuration wizard
   - Deploy

3. **Access Flipt** through configured ingress or LoadBalancer

## Option 3: Production Install

For production with HA:

```bash
helm install flipt ./chart \
  --namespace flipt \
  --create-namespace \
  --values examples/kubernetes/values-production.yaml \
  --wait
```

Access via your configured ingress hostname.

## Your First Feature Flag

### 1. Access the UI

Navigate to the Flipt UI (http://localhost:8080 if using port-forward).

### 2. Create a Flag

1. Click **"Flags"** in the sidebar
2. Click **"Create Flag"**
3. Fill in:
   - **Name**: `new_dashboard`
   - **Description**: `Enable the new dashboard UI`
   - **Type**: Boolean
4. Click **"Create"**

### 3. Enable the Flag

1. Toggle the flag to **Enabled**
2. Set a percentage rollout (e.g., 50%)
3. Click **"Save"**

### 4. Use the Flag in Your App

**Node.js:**
```javascript
const { FliptClient } = require('@flipt-io/flipt');

const flipt = new FliptClient({ url: 'http://localhost:8080' });

const result = await flipt.evaluateBoolean({
  namespaceKey: 'default',
  flagKey: 'new_dashboard',
  entityId: 'user-123',
  context: {}
});

if (result.enabled) {
  console.log('Show new dashboard!');
}
```

**Go:**
```go
import flipt "go.flipt.io/flipt/rpc/flipt"

client := flipt.NewFliptClient(conn)

resp, _ := client.EvaluateBoolean(ctx, &flipt.EvaluationRequest{
    NamespaceKey: "default",
    FlagKey:      "new_dashboard",
    EntityId:     "user-123",
})

if resp.Enabled {
    fmt.Println("Show new dashboard!")
}
```

**Python:**
```python
from flipt import FliptClient

client = FliptClient(url="http://localhost:8080")

result = client.evaluate_boolean(
    namespace_key="default",
    flag_key="new_dashboard",
    entity_id="user-123"
)

if result.enabled:
    print("Show new dashboard!")
```

## Verify Installation

Check that all components are running:

```bash
# Check pods
kubectl get pods -n flipt

# Should see:
# - flipt-flipt-xxx (2 replicas)
# - flipt-cluster-xxx (PostgreSQL)
# - flipt-redis-master-xxx

# Check services
kubectl get svc -n flipt

# Check ingress (if enabled)
kubectl get ingress -n flipt
```

## Common Commands

```bash
# View logs
kubectl logs -l app.kubernetes.io/name=flipt -n flipt --tail=100 -f

# Restart Flipt
kubectl rollout restart deployment/flipt-flipt -n flipt

# Scale Flipt
kubectl scale deployment/flipt-flipt -n flipt --replicas=3

# Check database status
kubectl get cluster -n flipt

# Check Redis status
kubectl get pods -l app.kubernetes.io/name=redis -n flipt
```

## Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod <pod-name> -n flipt
kubectl logs <pod-name> -n flipt
```

### Can't Access UI

```bash
# Verify service is running
kubectl get svc flipt-flipt -n flipt

# Check if port-forward is working
kubectl port-forward -n flipt svc/flipt-flipt 8080:8080

# Test locally
curl http://localhost:8080/health
```

### Database Connection Issues

```bash
# Check PostgreSQL cluster
kubectl get cluster -n flipt

# Check PostgreSQL logs
kubectl logs -l cnpg.io/cluster=flipt-cluster -n flipt
```

## Next Steps

1. **Set up ingress** for external access
2. **Configure authentication** for API security
3. **Enable metrics** for monitoring
4. **Create targeting rules** for user segmentation
5. **Integrate SDKs** into your applications

## Resources

- 📖 [Full Documentation](../README.md)
- 💻 [SDK Examples](examples/sdk/)
- ⚙️ [Configuration Examples](examples/kubernetes/)
- 🆘 [Troubleshooting Guide](../README.md#troubleshooting)

## Uninstall

```bash
# Uninstall Flipt
helm uninstall flipt --namespace flipt

# Remove namespace and PVCs
kubectl delete namespace flipt
```

## Support

- **Flipt Issues**: https://github.com/flipt-io/flipt/issues
- **Helm Chart Issues**: https://github.com/flipt-io/helm-charts/issues
- **Replicated Support**: https://support.replicated.com
