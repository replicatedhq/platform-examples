# CodiMD Deployment TODOs

## Testing Issues

### Cluster Creation and Deployment

- ✅ Cluster creation works properly using `task create-cluster`
- ✅ Kubeconfig setup works properly using `task setup-kubeconfig`
- ✅ Helm chart validation passes after configuration fixes
- ❓ Helm chart deployment needs testing with clean namespace

### Helm Chart Issues

1. **PostgreSQL Dependency Problems**: ✅ Fixed
   - ✅ Added global PostgreSQL auth configuration to fix template errors
   - ✅ Fixed `nil pointer evaluating interface {}.username` error in PostgreSQL helpers template
   - ✅ Fixed `nil pointer evaluating interface {}.existingSecret` error in PostgreSQL secret name template

2. **Redis Configuration**: ✅ Fixed
   - ✅ Reduced Redis replica count from 3 to 1 to minimize resource usage

3. **Chart Version Compatibility**: ✅ Fixed
   - ✅ Current PostgreSQL chart (v12.0.1) now works with updated global auth values
   - ✅ Global PostgreSQL auth values now properly recognized by the chart

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
