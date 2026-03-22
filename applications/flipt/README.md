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
- ✅ Valkey distributed caching for high performance
- ✅ Horizontal pod autoscaling support
- ✅ TLS/Ingress Gateway configuration
- ✅ Replicated SDK integration for enterprise management
- ✅ Comprehensive monitoring and metrics
- ✅ Support bundle generation for troubleshooting

## Architecture

```bash
┌─────────────────────────────────────────────────────────────┐
│             Load Balancer or Nodeport                       │
│                 (Ingress Gateway)                           │
└─────────────────┬───────────────────────────────────────────┘
                  │
        ┌─────────▼─────────┐
        │   Flipt Service   │
        │  (2+ replicas)    │
        │  HTTP + gRPC      │
        └──────┬────────┬───┘
               │        │
     ┌─────────▼──┐  ┌─▼──────────┐
     │ PostgreSQL │  │   Valkey    │
     │  (CNPG)    │  │  (Cache)   │
     └────────────┘  └────────────┘
```

### Components

1. **Flipt Server**: Core application handling feature flag evaluation and management
2. **PostgreSQL**: Durable storage for feature flag definitions and metadata (CloudnativePG operator)
3. **Valkey**: Distributed cache for high-performance flag evaluation (required for multiple replicas)
4. **Ingress Gateway**: External access with TLS support

## Prerequisites

- Kubernetes 1.24.0+
- Helm 3.8+
- Minimum resources:
  - 2 CPU cores
  - 4GB RAM
  - Default storage class with RWO support
- **CloudNativePG operator** (for embedded PostgreSQL)
  - Install once per cluster (see installation instructions below)
- (Optional) Envoy Gateway (included in Embedded Cluster; required for standalone ingress)
- (Optional) cert-manager for automated TLS certificates

## Installation

### Using Replicated Admin Console (KOTS)

1. **Install the application** through the Replicated admin console
2. **Configure settings** in the admin console UI:
   - Ingress Gateway and TLS settings
   - Database configuration (embedded or external)
   - Valkey cache settings
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

See the [Quickstart](./QUICKSTART.md) for install methods and creating your first Flipt feature flag, plus integration with your app code.

## Flipt Advanced Features

### Percentage Rollouts

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

Enable autoscaling for automatic pod scaling, configure this via the Admin Console which in turn will configure the Helm values as per below.

```yaml
flipt:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 80
```

### Database HA

For production, use 3 PostgreSQL instances, configure this via the Admin Console which in turn will configure the Helm values as per below.

```yaml
postgresql:
  embedded:
    cluster:
      instances: 3
```

## Monitoring

### Prometheus Metrics

Enable metrics collection, configure this via the Admin Console which in turn will configure the Helm values as per below.

```yaml
flipt:
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

Via Replicated Admin Console: Navigate to Troubleshoot > Generate Support Bundle

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

#### Valkey Connection Issues

Check Valkey status:

```bash
kubectl get pods -l app.kubernetes.io/name=valkey -n flipt
kubectl logs -l app.kubernetes.io/name=valkey -n flipt
```

#### Cache Not Working

Verify Valkey is enabled and Flipt can connect:

```bash
kubectl exec -it deploy/flipt-flipt -n flipt -- sh
# Inside the pod:
nc -zv flipt-valkey 6379
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

### Upgrade via Replicated Admin Console

1. Navigate to Version History
2. Select the new version
3. Review changes
4. Deploy

### Upgrade via Helm

```bash
helm upgrade flipt ./chart \
  --namespace flipt \
  --values custom-values.yaml
```

## Uninstallation

### Uninstall via Replicated Admin Console

Navigate to application settings and select "Remove Application"

### Uninstall via Helm

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

### Valkey Optimization

```yaml
valkey:
  resources:
    limits:
      memory: 2Gi
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

- **Flipt Documentation**: <https://docs.flipt.io>
- **API Reference**: <https://docs.flipt.io/reference/overview>
- **SDKs**: <https://docs.flipt.io/integration>
- **GitHub**: <https://github.com/flipt-io/flipt>
- **Discord Community**: <https://discord.gg/kRhEqG2T>
- **Replicated Documentation**: <https://docs.replicated.com>

## Support

For issues with:

- **Flipt application**: <https://github.com/flipt-io/flipt/issues>
- **Helm chart/deployment**: <https://github.com/flipt-io/helm-charts/issues>
- **Replicated integration**: <https://support.replicated.com>

## License

- Flipt is licensed under GPL-3.0
- This Helm chart follows the same GPL-3.0 license
- Replicated SDK has its own licensing terms
