# Flipt Examples

This directory contains examples for deploying and using Flipt in various scenarios.

## Directory Structure

```
examples/
├── kubernetes/         # Kubernetes deployment examples
│   ├── values-minimal.yaml
│   ├── values-production.yaml
│   └── values-external-db.yaml
└── sdk/               # SDK integration examples
    ├── nodejs-example.js
    ├── golang-example.go
    └── python-example.py
```

## Kubernetes Deployment Examples

### Minimal Setup (Development/Testing)

The minimal configuration is perfect for local development or testing:

```bash
helm install flipt ../chart \
  --namespace flipt \
  --create-namespace \
  --values kubernetes/values-minimal.yaml
```

Features:
- Single Flipt replica
- Embedded PostgreSQL (1 instance)
- Redis standalone
- No ingress (use port-forward)

Access:
```bash
kubectl port-forward -n flipt svc/flipt-flipt 8080:8080
```

### Production Setup (High Availability)

The production configuration provides a highly available deployment:

```bash
helm install flipt ../chart \
  --namespace flipt \
  --create-namespace \
  --values kubernetes/values-production.yaml
```

Features:
- 3 Flipt replicas with autoscaling
- PostgreSQL cluster (3 instances)
- Redis primary-replica architecture
- Ingress with TLS
- Prometheus metrics
- Pod disruption budgets

### External Database Setup

Use this when you have an existing PostgreSQL database:

```bash
helm install flipt ../chart \
  --namespace flipt \
  --create-namespace \
  --values kubernetes/values-external-db.yaml
```

**⚠️ Important:** Update the database credentials before deploying!

## SDK Integration Examples

### Node.js

The Node.js example demonstrates:
- Simple boolean flag evaluation
- Variant flags for A/B testing
- Batch flag evaluation
- Express middleware integration
- Local caching with TTL

**Run the example:**

```bash
cd sdk
npm install @flipt-io/flipt
export FLIPT_URL=http://localhost:8080
node nodejs-example.js
```

**Key features:**
- ✅ Boolean flags
- ✅ Variant flags (A/B testing)
- ✅ Batch evaluation
- ✅ Express middleware
- ✅ Caching layer
- ✅ Error handling

### Go

The Go example demonstrates:
- gRPC client integration
- Boolean and variant flag evaluation
- HTTP middleware
- Cached client with TTL
- Production-ready patterns

**Run the example:**

```bash
cd sdk
go mod init example
go get go.flipt.io/flipt/rpc/flipt
export FLIPT_ADDR=localhost:9000
go run golang-example.go
```

**Key features:**
- ✅ gRPC client
- ✅ Boolean flags
- ✅ Variant flags
- ✅ HTTP middleware
- ✅ Client-side caching
- ✅ Context propagation

### Python

The Python example demonstrates:
- HTTP REST API client
- Flask middleware integration
- Django middleware integration
- FastAPI dependency injection
- Caching with TTL

**Run the example:**

```bash
cd sdk
pip install requests flask  # or django, or fastapi
export FLIPT_URL=http://localhost:8080
python python-example.py
```

**Key features:**
- ✅ REST API client
- ✅ Flask integration
- ✅ Django integration
- ✅ FastAPI integration
- ✅ Client-side caching
- ✅ Error handling

## Common Use Cases

### 1. Feature Rollout

Gradually enable a feature for increasing percentages of users:

```javascript
// Week 1: 10% rollout
// Week 2: 25% rollout
// Week 3: 50% rollout
// Week 4: 100% rollout

const enabled = await flipt.evaluateBoolean({
  flagKey: 'new_feature',
  entityId: userId,
  context: { /* user attributes */ }
});
```

### 2. User Targeting

Enable features for specific user segments:

```javascript
const enabled = await flipt.evaluateBoolean({
  flagKey: 'premium_feature',
  entityId: userId,
  context: {
    plan: 'enterprise',
    email: user.email
  }
});
```

### 3. A/B Testing

Run experiments with multiple variants:

```javascript
const variant = await flipt.evaluateVariant({
  flagKey: 'checkout_experiment',
  entityId: userId,
  context: { /* user attributes */ }
});

switch (variant.variantKey) {
  case 'control':
    // Original experience
    break;
  case 'variant_a':
    // Variant A experience
    break;
  case 'variant_b':
    // Variant B experience
    break;
}
```

### 4. Kill Switch

Instantly disable a problematic feature:

```javascript
// Simply toggle the flag off in Flipt UI
// All evaluations will immediately return false
const enabled = await flipt.evaluateBoolean({
  flagKey: 'problematic_feature',
  entityId: userId
});
```

### 5. Environment-Specific Config

Different behavior per environment:

```javascript
// In Flipt, set different values per environment:
// - dev: feature_enabled = true
// - staging: feature_enabled = true
// - production: feature_enabled = false

const enabled = await flipt.evaluateBoolean({
  namespaceKey: process.env.ENVIRONMENT,
  flagKey: 'experimental_feature',
  entityId: userId
});
```

## Best Practices

### 1. Always Provide Default Values

```javascript
const enabled = client.evaluateBoolean(/* ... */) || false;
```

### 2. Use Caching for High-Traffic Endpoints

```javascript
const cachedClient = new CachedFliptClient(client, 60000); // 1 min TTL
```

### 3. Handle Errors Gracefully

```javascript
try {
  const enabled = await client.evaluateBoolean(/* ... */);
} catch (error) {
  // Log error and return safe default
  console.error('Flag evaluation failed:', error);
  return false;
}
```

### 4. Use Meaningful Entity IDs

```javascript
// Good: Consistent user identifier
entityId: user.id

// Bad: Random or changing identifiers
entityId: Math.random()
```

### 5. Provide Rich Context

```javascript
context: {
  email: user.email,
  plan: user.subscription.plan,
  region: user.region,
  accountAge: calculateAge(user.createdAt),
  // Add any attribute you might want to target on
}
```

### 6. Monitor Flag Evaluations

```javascript
const result = await client.evaluateBoolean(/* ... */);

// Log or send metrics
metrics.increment('flipt.evaluation', {
  flag: 'feature_name',
  result: result.enabled
});
```

## Testing Feature Flags

### Unit Tests

Mock the Flipt client in your tests:

```javascript
// Jest example
jest.mock('@flipt-io/flipt');

test('shows new dashboard when flag enabled', () => {
  FliptClient.prototype.evaluateBoolean.mockResolvedValue({
    enabled: true
  });

  // Test code that uses the flag
});
```

### Integration Tests

Use a test Flipt instance:

```javascript
const testClient = new FliptClient({
  url: 'http://flipt-test:8080'
});
```

### Local Development

Override flags for development:

```javascript
const FEATURE_OVERRIDES = {
  'new_feature': process.env.NODE_ENV === 'development'
};

const enabled = FEATURE_OVERRIDES[flagKey] ??
  await client.evaluateBoolean(/* ... */);
```

## Troubleshooting

### Connection Issues

```bash
# Check Flipt is accessible
curl http://flipt.flipt.svc.cluster.local:8080/health

# Port forward for local testing
kubectl port-forward -n flipt svc/flipt-flipt 8080:8080
```

### Cache Issues

```javascript
// Clear cache if flags aren't updating
cachedClient.cache.clear();
```

### Debug Logging

```javascript
// Enable debug logging
const client = new FliptClient({
  url: 'http://flipt:8080',
  debug: true
});
```

## Additional Resources

- [Flipt Documentation](https://docs.flipt.io)
- [SDK Reference](https://docs.flipt.io/integration)
- [API Documentation](https://docs.flipt.io/reference/overview)
- [Best Practices](https://docs.flipt.io/guides/best-practices)

## Contributing

Have a useful example? Please contribute!

1. Add your example to the appropriate directory
2. Update this README
3. Submit a pull request

## License

Examples are provided under the same license as the parent repository.
