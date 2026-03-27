# Flipt Quick Start Guide

Get up and running with Flipt in 5 minutes.

## Prerequisites

- Kubernetes cluster (1.24+)
- Helm 3.8+
- kubectl configured
- A Replicated development license (see [Getting a Development License](#getting-a-development-license) below)

## Getting a Development License

Flipt integrates with the Replicated SDK & KOTS to provide admin console integration, preflight checks, support bundle generation, and license enforcement. A valid license is required even in development environments.

### 1. Install the Replicated CLI

```bash
# macOS
brew install replicatedhq/replicated/cli

# Linux/macOS (alternative)
curl -s https://api.github.com/repos/replicatedhq/replicated/releases/latest | \
  grep "browser_download_url.*$(uname -s)_$(uname -m)" | \
  cut -d '"' -f 4 | \
  xargs curl -L -o replicated
chmod +x replicated
sudo mv replicated /usr/local/bin/
```

Verify: `replicated version`

### 2. Get a Replicated API Token

1. Log in to [vendor.replicated.com](https://vendor.replicated.com)
2. Navigate to **Settings** > **Service Accounts**
3. Click **Create Service Account** and copy the token
4. Export it:

   ```bash
   export REPLICATED_API_TOKEN=your-token-here
   ```

### 3. Create a Development Customer and License

```bash
replicated customer create \
  --app flipt \
  --name "dev-$(whoami)" \
  --channel Unstable \
  --type dev \
  --output json > customer.json

export REPLICATED_LICENSE_ID=$(jq -r '.id' customer.json)
```

### Managing Licenses

```bash
# List licenses
replicated customer ls

# Delete a license
replicated customer rm --customer "customer-name"

# Delete all dev licenses
replicated customer ls --output json | \
  jq -r '.[] | select(.licenseType == "dev") | .name' | \
  xargs -I {} replicated customer rm --customer {}
```

If your license expires, delete it with `replicated customer rm` and create a new one using the steps above.

## Option 1: Manual Helm Install on local machine

```bash
# Step 1: Update chart dependencies (includes CloudNativePG operator)
cd chart
rm -f Chart.lock  # Clean cached files
helm repo add flipt https://helm.flipt.io
helm repo add valkey https://valkey.io/valkey-helm/
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

Open your browser to: <http://localhost:8080>

## Option 2: Replicated Embedded Cluster/KOTS Install

For enterprise deployments with Admin Console:

1. **Upload the application** to your Replicated vendor portal:

   ```bash
   export REPLICATED_APP=flipt
   make release
   ```

2. **Install via Replicated Admin Console**:
   - Log into your Replicated Admin Console
   - Select the Flipt application
   - Follow the configuration wizard
   - Deploy

3. **Access Flipt** through configured Ingress or LoadBalancer

## Option 3: Production Install to existing K8s Cluster

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

Navigate to the Flipt UI <http://localhost:8080> if using port-forward).

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
2. Set a percentage rollout under 'Rollouts'(e.g., 50%)
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

```bash
# Check pods
kubectl get pods -n flipt

# Should see:
# - flipt-flipt-xxx (2 replicas)
# - flipt-cluster-xxx (PostgreSQL)
# - flipt-valkey-xxx

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

# Check Valkey status
kubectl get pods -l app.kubernetes.io/name=valkey -n flipt
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

### License Errors

```bash
# "replicated: command not found" — install the CLI (see Getting a Development License above)

# "unauthorized: authentication required"
replicated api version  # verify token is valid
export REPLICATED_API_TOKEN=new-token

# "license not found" — verify or recreate the secret
kubectl get secret replicated-license -n flipt
kubectl create secret generic replicated-license \
  --from-literal=license="$REPLICATED_LICENSE_ID" \
  --namespace flipt

# Replicated SDK logs
kubectl logs -l app=replicated -n flipt
```

### Running Without a License (not recommended)

If you need to run without a license for testing purposes:

```bash
helm install flipt ./chart \
  --namespace flipt \
  --create-namespace \
  --set replicated.enabled=false
```

**Note:** This disables all Replicated features including support bundles and preflight checks.

## Next Steps

1. **Set up ingress** for external access
2. **Configure authentication** for API security
3. **Enable metrics** for monitoring
4. **Create targeting rules** for user segmentation
5. **Integrate SDKs** into your applications

## Resources

- [Full Documentation](README.md)
- [SDK Examples](examples/sdk/)
- [Configuration Examples](examples/kubernetes/)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Replicated CLI Documentation](https://docs.replicated.com/reference/replicated-cli)
- [License Types](https://docs.replicated.com/vendor/licenses-about)

## Uninstall

```bash
helm uninstall flipt --namespace flipt
kubectl delete namespace flipt
```

## Support

- **Flipt Issues**: <https://github.com/flipt-io/flipt/issues>
- **Helm Chart Issues**: <https://github.com/flipt-io/helm-charts/issues>
- **Replicated Support**: <https://support.replicated.com>
