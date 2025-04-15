# CodiMD Deployment TODOs

## Testing Issues

### Cluster Creation and Deployment
- ✅ Cluster creation works properly using `task create-cluster`
- ✅ Kubeconfig setup works properly using `task setup-kubeconfig`
- ❌ Helm chart deployment fails with dependency issues

### Helm Chart Issues
1. **PostgreSQL Dependency Problems**:
   - Template errors related to missing PostgreSQL auth configuration
   - Error: `nil pointer evaluating interface {}.username` in PostgreSQL helpers template
   - Error: `nil pointer evaluating interface {}.existingSecret` in PostgreSQL secret name template

2. **Chart Version Compatibility**:
   - Current PostgreSQL chart (v12.0.1) has template structure requiring specific auth configuration
   - The global PostgreSQL auth values are not properly recognized by the chart

## Proposed Solutions

### Short-term Fixes
1. Update the `values.yaml` file to properly configure PostgreSQL auth:
   - Ensure all required auth parameters are correctly set
   - Make sure global PostgreSQL values are correctly structured

2. Test with specific chart versions:
   - Pin PostgreSQL chart to a version compatible with our configuration
   - Test with a simpler configuration that doesn't require complex auth setup

### Long-term Improvements
1. Simplify the chart dependencies:
   - Consider using bitnami/postgresql chart directly instead of embedding it
   - Document the exact chart versions that work with our setup

2. Improve CI testing:
   - Add automated tests for chart deployment
   - Implement pre-release validation of chart dependencies

## Testing Process Improvements
1. Document standard testing procedure
2. Create test values file with minimal working configuration
3. Add debugging information for common errors