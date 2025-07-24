# Phase 4 Implementation Plan: Test Deployment Action Refactoring

## Overview

Phase 4 focuses on decomposing the complex `.github/actions/test-deployment` composite action into individual workflow steps while preserving the helmfile orchestration architecture. This phase will complete the transition from custom Task-based actions to official replicated-actions for resource management.

## Current State Analysis

### Existing `.github/actions/test-deployment` Structure

The current composite action performs the following operations:

1. **Resource Creation** (via Tasks)
   - `task customer-create` → Creates customer in Replicated
   - `task utils:get-customer-license` → Retrieves license for customer
   - `task cluster-create` → Creates test cluster
   - `task setup-kubeconfig` → Configures kubectl access

2. **Deployment** (via Task + Helmfile)
   - `task customer-helm-install` → Deploys charts using helmfile orchestration
   - Port exposure and configuration
   - Health checks and validation

3. **Testing** (via Task)
   - `task test` → Runs application tests against deployed environment

### Critical Constraint

The `task customer-helm-install` operation **MUST** be preserved as it provides:
- Multi-chart orchestration via helmfile
- Environment-specific configuration (replicated vs default)
- Registry proxy support for Replicated environment
- Complex dependency management between charts
- Unified configuration management across charts

## Implementation Strategy

### Step 1: Resource Management Decomposition

Replace the resource creation Tasks with official replicated-actions that were completed in Phase 3:

**Before (Custom Composite Action):**
```yaml
- name: Create customer
  run: task customer-create CUSTOMER_NAME=${{ inputs.customer-name }}
- name: Get license
  run: task utils:get-customer-license CUSTOMER_NAME=${{ inputs.customer-name }}
- name: Create cluster
  run: task cluster-create CLUSTER_NAME=${{ inputs.cluster-name }}
- name: Setup kubeconfig
  run: task setup-kubeconfig CLUSTER_NAME=${{ inputs.cluster-name }}
```

**After (Individual Workflow Steps):**
```yaml
- name: Create customer
  id: create-customer
  uses: replicatedhq/replicated-actions/create-customer@v1.19.0
  with:
    api-token: ${{ secrets.REPLICATED_API_TOKEN }}
    customer-name: ${{ inputs.customer-name }}
    channel-slug: ${{ inputs.channel-slug }}
    
- name: Create cluster
  id: create-cluster
  uses: replicatedhq/replicated-actions/create-cluster@v1.19.0
  with:
    api-token: ${{ secrets.REPLICATED_API_TOKEN }}
    cluster-name: ${{ inputs.cluster-name }}
    distribution: k3s
    version: "1.32.2"
```

### Step 2: Preserve Helmfile Orchestration

The deployment step will continue using the Task-based approach but with inputs from official actions:

```yaml
- name: Deploy application
  run: |
    task customer-helm-install \
      CUSTOMER_NAME=${{ inputs.customer-name }} \
      CLUSTER_NAME=${{ inputs.cluster-name }} \
      REPLICATED_LICENSE_ID=${{ steps.create-customer.outputs.license-id }} \
      CHANNEL_SLUG=${{ inputs.channel-slug }}
  env:
    KUBECONFIG: ${{ steps.create-cluster.outputs.kubeconfig }}
  timeout-minutes: 20
```

### Step 3: Testing Integration

Preserve the existing test execution with proper environment setup:

```yaml
- name: Run tests
  run: task test
  env:
    KUBECONFIG: ${{ steps.create-cluster.outputs.kubeconfig }}
  timeout-minutes: 10
```

## Detailed Implementation Plan

### Phase 4.1: Action Decomposition

#### Task 4.1.1: Remove Custom Composite Action

- [ ] Delete `.github/actions/test-deployment/action.yml`
- [ ] Update workflows to use individual steps instead of composite action
- [ ] Maintain all existing functionality through direct workflow steps

#### Task 4.1.2: Update Workflow Integration

- [ ] Modify `wg-easy-pr-validation.yaml` to use individual steps
- [ ] Update input/output parameter handling
- [ ] Ensure proper step dependency management

### Phase 4.2: Resource Management Integration

**Task 4.2.1: Customer Management**

- [ ] Replace `task customer-create` with `replicatedhq/replicated-actions/create-customer@v1.19.0`
- [ ] Use action outputs for license-id instead of separate lookup
- [ ] Handle channel-slug parameter conversion from channel-id if needed

**Task 4.2.2: Cluster Management**

- [ ] Replace `task cluster-create` with `replicatedhq/replicated-actions/create-cluster@v1.19.0`
- [ ] Use action outputs for kubeconfig instead of separate setup
- [ ] Maintain cluster configuration parameters (distribution, version, etc.)

**Task 4.2.3: Environment Configuration**

- [ ] Ensure KUBECONFIG environment variable is properly set from action outputs
- [ ] Maintain port exposure functionality via `task cluster-ports-expose`
- [ ] Preserve all existing cluster configuration options

### Phase 4.3: Deployment Preservation

**Task 4.3.1: Helmfile Integration**

- [ ] Preserve `task customer-helm-install` for helmfile orchestration
- [ ] Pass license-id and cluster information from action outputs
- [ ] Maintain environment-specific configuration (replicated vs default)

**Task 4.3.2: Registry Proxy Support**

- [ ] Ensure Replicated registry proxy configuration remains functional
- [ ] Maintain image rewriting for replicated environment
- [ ] Preserve multi-chart deployment capabilities

### Phase 4.4: Testing and Validation

**Task 4.4.1: Test Execution**

- [ ] Preserve `task test` functionality with proper environment setup
- [ ] Ensure kubeconfig is available for test execution
- [ ] Maintain test timeout and error handling

**Task 4.4.2: End-to-End Validation**

- [ ] Test complete workflow from resource creation to deployment
- [ ] Validate all chart deployments function correctly
- [ ] Ensure test execution works with new resource management

## Benefits Analysis

### Immediate Benefits

1. **Reduced Complexity**: Eliminates complex composite action in favor of clear workflow steps
2. **Better Visibility**: Each step shows individual progress in GitHub Actions UI
3. **Improved Debugging**: Easier to identify and troubleshoot specific failures
4. **Consistent Error Handling**: Official actions provide standardized error messages

### Long-term Benefits

1. **Reduced Maintenance**: Official actions are maintained by Replicated team
2. **Enhanced Features**: Access to new features and improvements in official actions
3. **Better Documentation**: Official actions have comprehensive documentation
4. **Improved Reliability**: Professional testing and validation of official actions

### Preserved Functionality

1. **Helmfile Orchestration**: Multi-chart deployment capabilities maintained
2. **Environment Configuration**: Replicated vs default environment handling preserved
3. **Registry Proxy**: Image rewriting and proxy functionality maintained
4. **Complex Dependencies**: Chart dependency management preserved

## Risk Assessment

### Low Risk

- Resource creation replacement (already validated in Phase 3)
- Output parameter handling (established patterns)
- Environment variable management (straightforward)

### Medium Risk

- Workflow step dependency management
- Timeout configuration across multiple steps
- Error handling between individual steps

### Mitigation Strategies

1. **Comprehensive Testing**: Full end-to-end testing before deployment
2. **Gradual Rollout**: Test in feature branch before main integration
3. **Rollback Plan**: Maintain ability to revert to composite action if needed
4. **Documentation**: Detailed documentation of changes and configurations

## Success Criteria

### Functional Requirements

- [ ] All existing workflow functionality preserved
- [ ] Resource creation works with official actions
- [ ] Helmfile deployment continues to function
- [ ] Tests execute successfully in new environment
- [ ] Error handling works correctly across all steps

### Performance Requirements

- [ ] Total workflow execution time remains comparable
- [ ] Resource creation time improves with official actions
- [ ] Deployment time remains unchanged (helmfile preserved)
- [ ] Test execution time remains unchanged

### Quality Requirements

- [ ] Improved visibility in GitHub Actions UI
- [ ] Clear error messages for troubleshooting
- [ ] Consistent logging across all steps
- [ ] Proper resource cleanup on failure

## Implementation Timeline

### Week 1: Preparation
- [ ] Analyze current composite action structure
- [ ] Design new workflow step architecture
- [ ] Prepare test environment for validation

### Week 2: Core Implementation
- [ ] Implement resource management with official actions
- [ ] Update workflow to use individual steps
- [ ] Preserve helmfile deployment integration

### Week 3: Testing and Validation
- [ ] End-to-end testing of new workflow
- [ ] Performance comparison with current implementation
- [ ] Error handling validation

### Week 4: Deployment and Documentation
- [ ] Deploy to main branch
- [ ] Update documentation
- [ ] Monitor workflow performance

## Conclusion

Phase 4 represents the final major step in the replicated-actions refactoring effort. By decomposing the complex composite action while preserving the critical helmfile orchestration, we achieve the benefits of official actions while maintaining the sophisticated deployment capabilities required for multi-chart applications.

The key to success is maintaining the hybrid approach: official actions for resource management and Task-based operations for complex deployment orchestration. This provides the best of both worlds - improved reliability and reduced maintenance burden while preserving the advanced features necessary for enterprise application deployment.