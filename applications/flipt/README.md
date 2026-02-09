# Flipt Feature Flags

Enterprise-ready deployment of [Flipt](https://flipt.io), an open-source, self-hosted feature flag and experimentation platform, integrated with Replicated for streamlined Kubernetes deployment.

## Overview

Flipt enables teams to:

- **Deploy features gradually** with percentage-based rollouts
- **Target specific users** with advanced segmentation rules
- **Run A/B tests** and experiments safely
- **Manage feature flags** across multiple environments
- **Reduce deployment risk** with instant kill switches

This Helm chart provides a production-ready deployment with:

- ✅ PostgreSQL database (embedded via CloudnativePG or external)
- ✅ Redis distributed caching for high performance
- ✅ Horizontal pod autoscaling support
- ✅ TLS/ingress configuration
- ✅ Replicated SDK integration for enterprise management
- ✅ Comprehensive monitoring and metrics
- ✅ Support bundle generation for troubleshooting

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Load Balancer                          │
│                         (Ingress)                            │
└─────────────────┬───────────────────────────────────────────┘
                  │
        ┌─────────▼─────────┐
        │   Flipt Service   │
        │  (2+ replicas)    │
        │  HTTP + gRPC      │
        └──────┬────────┬───┘
               │        │
     ┌─────────▼──┐  ┌─▼──────────┐
     │ PostgreSQL │  │   Redis    │
     │  (CNPG)    │  │  (Cache)   │
     └────────────┘  └────────────┘
```

### Components

1. **Flipt Server**: Core application handling feature flag evaluation and management
2. **PostgreSQL**: Durable storage for feature flag definitions and metadata (CloudnativePG operator)
3. **Redis**: Distributed cache for high-performance flag evaluation (required for multiple replicas)
4. **Ingress**: External access with TLS support

## Prerequisites

- Kubernetes 1.24.0+
- Helm 3.8+
- Minimum resources:
  - 2 CPU cores
  - 4GB RAM
  - Default storage class with RWO support
- **CloudNativePG operator** (for embedded PostgreSQL)
  - Install once per cluster (see installation instructions below)
- (Optional) Ingress controller (NGINX, Traefik, etc.)
- (Optional) cert-manager for automated TLS certificates

## Installation

### Using Replicated Admin Console (KOTS)

1. **Install the application** through the Replicated admin console
2. **Configure settings** in the admin console UI:
   - Ingress and TLS settings
   - Database configuration (embedded or external)
   - Redis cache settings
   - Resource limits
3. **Deploy** and monitor via the admin console

The admin console provides:
- One-click deployment
- Configuration validation
- Preflight checks
- Automated updates
- Support bundle generation

### Using Helm Directly

**✨ Note:** The CloudNativePG operator is now included as a chart dependency and will be installed automatically.

### Important: Replicated License Required

Flipt requires a Replicated development license for local testing. This provides access to:
- Replicated SDK integration
- Admin console features
- Preflight checks
- Support bundle generation

**Quick Setup:**
```bash
# 1. Set up development license
export REPLICATED_API_TOKEN=your-token
export REPLICATED_LICENSE_ID=your-license-id
```

**Detailed instructions:** See [Development License Guide](docs/DEVELOPMENT_LICENSE.md)

1. **Add the Helm repositories:**

   ```bash
   helm repo add flipt-repo https://helm.flipt.io
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm repo add replicated https://charts.replicated.com
   helm repo update
   ```

3. **Install the chart:**

   ```bash
   cd chart
   helm dependency update
   cd ..

   helm install flipt ./chart \
     --namespace flipt \
     --create-namespace \
     --values custom-values.yaml \
     --timeout 10m
   ```

4. **Wait for deployment:**

   ```bash
   kubectl wait --for=condition=ready pod \
     -l app.kubernetes.io/name=flipt \
     -n flipt \
     --timeout=5m
   ```

## Configuration

### Key Configuration Options

The chart can be configured via `values.yaml` or the Replicated admin console:

#### Flipt Application

```yaml
flipt:
  replicaCount: 2  # Number of Flipt pods (2+ recommended with Redis)
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi
```

#### PostgreSQL Database

```yaml
postgresql:
  type: embedded  # 'embedded' or 'external'

  # Embedded database (CloudnativePG)
  embedded:
    enabled: true
    cluster:
      instances: 1  # 3 for HA
      storage:
        size: 10Gi
        storageClass: ""
```

#### Redis Cache

```yaml
redis:
  enabled: true  # Required for multiple Flipt replicas
  architecture: standalone  # or 'replication' for HA
  auth:
    enabled: true
    password: ""  # Auto-generated if empty
  master:
    persistence:
      enabled: true
      size: 5Gi
```

#### Ingress

```yaml
flipt:
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: flipt.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: flipt-tls
        hosts:
          - flipt.example.com
```

## Accessing Flipt

### Via Ingress

If ingress is enabled, access Flipt at your configured hostname:

```
https://flipt.example.com
```

### Via Port Forward

For local access without ingress:

```bash
kubectl port-forward -n flipt svc/flipt-flipt 8080:8080
```

Then open: http://localhost:8080

### Via LoadBalancer

Change the service type to LoadBalancer:

```yaml
flipt:
  service:
    type: LoadBalancer
```

## Using Flipt

### 1. Create Your First Feature Flag

Navigate to the Flipt UI and:

1. Create a new flag (e.g., `new_dashboard`)
2. Set the flag type (boolean, variant, etc.)
3. Configure targeting rules (optional)
4. Enable the flag

### 2. Integrate with Your Application

#### Node.js Example

```javascript
const { FliptClient } = require('@flipt-io/flipt');

const client = new FliptClient({
  url: 'http://flipt.example.com',
});

// Evaluate a boolean flag
const result = await client.evaluateBoolean({
  namespaceKey: 'default',
  flagKey: 'new_dashboard',
  entityId: 'user-123',
  context: {
    email: 'user@example.com',
    plan: 'enterprise'
  }
});

if (result.enabled) {
  // Show new dashboard
}
```

#### Go Example

```go
import (
    "context"
    flipt "go.flipt.io/flipt/rpc/flipt"
    "google.golang.org/grpc"
)

conn, _ := grpc.Dial("flipt.example.com:9000", grpc.WithInsecure())
client := flipt.NewFliptClient(conn)

resp, _ := client.EvaluateBoolean(context.Background(), &flipt.EvaluationRequest{
    NamespaceKey: "default",
    FlagKey:      "new_dashboard",
    EntityId:     "user-123",
    Context: map[string]string{
        "email": "user@example.com",
        "plan":  "enterprise",
    },
})

if resp.Enabled {
    // Show new dashboard
}
```

#### Python Example

```python
from flipt import FliptClient

client = FliptClient(url="http://flipt.example.com")

result = client.evaluate_boolean(
    namespace_key="default",
    flag_key="new_dashboard",
    entity_id="user-123",
    context={
        "email": "user@example.com",
        "plan": "enterprise"
    }
)

if result.enabled:
    # Show new dashboard
```

### 3. Advanced Features

#### Percentage Rollouts

Gradually release features to a percentage of users:

```yaml
Rules:
  - Rollout: 25%  # Start with 25% of users
    Value: true
```

#### User Targeting

Target specific user segments:

```yaml
Rules:
  - Segment:
      Key: email
      Constraint: ends_with
      Value: "@enterprise.com"
    Value: true
```

#### A/B Testing

Create variant flags for experiments:

```yaml
Variants:
  - control: 50%
  - treatment_a: 25%
  - treatment_b: 25%
```

## Scaling & High Availability

### Horizontal Scaling

Enable autoscaling for automatic pod scaling:

```yaml
flipt:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 80
```

### Database HA

For production, use 3 PostgreSQL instances:

```yaml
postgresql:
  embedded:
    cluster:
      instances: 3
```

### Redis HA

Enable primary-replica architecture:

```yaml
redis:
  architecture: replication
  replica:
    replicaCount: 2
```

## Monitoring

### Prometheus Metrics

Enable metrics collection:

```yaml
flipt:
  serviceMonitor:
    enabled: true

redis:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
```

### Available Metrics

Flipt exposes metrics at `/metrics`:

- `flipt_evaluations_total` - Total number of flag evaluations
- `flipt_evaluation_duration_seconds` - Evaluation latency
- `flipt_cache_hits_total` - Cache hit count
- `flipt_cache_misses_total` - Cache miss count

## Troubleshooting

### Generate Support Bundle

Via Replicated admin console: Navigate to Troubleshoot > Generate Support Bundle

Via CLI:

```bash
kubectl support-bundle ./replicated/kots-support-bundle.yaml
```

### Common Issues

#### Pods Not Starting

Check pod status and events:

```bash
kubectl get pods -n flipt
kubectl describe pod <pod-name> -n flipt
```

#### Database Connection Issues

Check PostgreSQL cluster status:

```bash
kubectl get cluster -n flipt
kubectl logs -l cnpg.io/cluster=flipt-cluster -n flipt
```

#### Redis Connection Issues

Check Redis status:

```bash
kubectl get pods -l app.kubernetes.io/name=redis -n flipt
kubectl logs -l app.kubernetes.io/name=redis -n flipt
```

#### Cache Not Working

Verify Redis is enabled and Flipt can connect:

```bash
kubectl exec -it deploy/flipt-flipt -n flipt -- sh
# Inside the pod:
nc -zv flipt-redis-master 6379
```

### Debug Logs

Enable debug logging:

```yaml
flipt:
  config:
    log:
      level: debug
```

## Upgrading

### Via Replicated Admin Console

1. Navigate to Version History
2. Select the new version
3. Review changes
4. Deploy

### Via Helm

```bash
helm upgrade flipt ./chart \
  --namespace flipt \
  --values custom-values.yaml
```

## Uninstallation

### Via Replicated Admin Console

Navigate to application settings and select "Remove Application"

### Via Helm

```bash
helm uninstall flipt --namespace flipt
```

To also remove PVCs:

```bash
kubectl delete pvc --all -n flipt
```

## Security Considerations

1. **Enable TLS**: Always use TLS in production
2. **Authentication**: Configure authentication methods for the API
3. **Network Policies**: Restrict pod-to-pod communication
4. **Secrets Management**: Use external secret management for sensitive data
5. **RBAC**: Implement Kubernetes RBAC for admin access
6. **Regular Updates**: Keep Flipt and dependencies updated

### Authentication Setup

Flipt supports multiple authentication methods:

```yaml
flipt:
  config:
    authentication:
      methods:
        token:
          enabled: true
        # Or use OIDC
        oidc:
          enabled: true
          issuerURL: "https://accounts.google.com"
          clientID: "your-client-id"
          clientSecret: "your-client-secret"
```

## Performance Tuning

### Database Optimization

```yaml
postgresql:
  embedded:
    cluster:
      resources:
        limits:
          cpu: 2000m
          memory: 4Gi
      postgresql:
        parameters:
          max_connections: "200"
          shared_buffers: "1GB"
```

### Redis Optimization

```yaml
redis:
  master:
    resources:
      limits:
        memory: 2Gi
    persistence:
      enabled: true
      size: 20Gi
```

### Flipt Optimization

```yaml
flipt:
  config:
    db:
      maxOpenConn: 100
      maxIdleConn: 25
      connMaxLifetime: 1h
    cache:
      ttl: 10m  # Increase cache TTL for more stable flags
```

## Resources

- **Flipt Documentation**: https://docs.flipt.io
- **API Reference**: https://docs.flipt.io/reference/overview
- **SDKs**: https://docs.flipt.io/integration
- **GitHub**: https://github.com/flipt-io/flipt
- **Discord Community**: https://discord.gg/kRhEqG2T
- **Replicated Documentation**: https://docs.replicated.com

## Support

For issues with:
- **Flipt application**: https://github.com/flipt-io/flipt/issues
- **Helm chart/deployment**: https://github.com/flipt-io/helm-charts/issues
- **Replicated integration**: https://support.replicated.com

## License

- Flipt is licensed under GPL-3.0
- This Helm chart follows the same GPL-3.0 license
- Replicated SDK has its own licensing terms

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Changelog

### Version 1.0.0

- Initial release
- Flipt v1.61.0
- PostgreSQL 16 via CloudnativePG
- Redis 7.2 for distributed caching
- Replicated SDK integration
- Comprehensive KOTS configuration
- Preflight checks and support bundles
