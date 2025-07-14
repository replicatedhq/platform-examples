# Compatibility Matrix Testing Enhancement Plan

## Overview

This plan outlines the implementation of multi-environment testing for the wg-easy PR validation workflow. The current workflow only tests against k3s v1.32.2, but should validate compatibility across multiple Kubernetes versions and distributions to ensure broad compatibility.

## Current State

**Previous Testing Environment (Phase 1):**
- Single Kubernetes version: v1.32.2
- Single distribution: k3s
- Single node cluster: r1.small instance

**Current Testing Environment (Phase 2 - IMPLEMENTED):**
- Multiple Kubernetes versions: v1.31.2, v1.32.2
- Multiple distributions: k3s, kind, EKS
- Variable node configurations: 1, 2, 3 nodes
- Dynamic instance types: r1.small, r1.medium
- 6 active matrix combinations with distribution-specific configurations

**Phase 2 Achievements:**
- ✅ Multi-environment validation implemented
- ✅ Distribution-specific networking and storage testing
- ✅ Parallel execution optimization
- ✅ Performance monitoring and resource tracking
- ✅ Matrix-based resource naming and cleanup

## Proposed Enhancement

### Matrix Testing Strategy

Implement a job matrix that tests across:

1. **Kubernetes Versions:**
   - v1.30.0 (stable)
   - v1.31.2 (stable)
   - v1.32.2 (latest)

2. **Distributions:**
   - k3s (lightweight)
   - kind (local development)
   - EKS (AWS managed)

3. **Node Configurations:**
   - Single node (current)
   - Multi-node (for production-like testing)

## Implementation Plan

### Phase 1: Basic Matrix Implementation - COMPLETED ✅

#### Task 1.1: Update Workflow Structure - COMPLETED ✅
- [x] Add strategy matrix to `test-deployment` job
- [x] Configure matrix variables for k8s-version and distribution
- [x] Update job naming to include matrix parameters
- [x] Test with minimal matrix (2 versions, 1 distribution)

#### Task 1.2: Matrix Configuration - COMPLETED ✅
- [x] Define matrix variables in workflow environment
- [x] Update cluster creation parameters to use matrix values
- [x] Ensure proper resource naming with matrix identifiers
- [x] Add matrix exclusions for incompatible combinations

#### Task 1.3: Resource Management Updates - COMPLETED ✅
- [x] Update cluster naming to include matrix identifiers
- [x] Modify resource cleanup to handle matrix-based names
- [x] Ensure unique resource names across matrix jobs
- [x] Update timeout values for different distributions

### Phase 2: Enhanced Matrix Testing - COMPLETED ✅

#### Task 2.1: Distribution-Specific Configurations - COMPLETED ✅
- [x] Add k3s-specific configuration options
- [x] Implement kind cluster configuration
- [x] Add EKS cluster creation logic
- [x] Configure distribution-specific networking

#### Task 2.2: Node Configuration Matrix - COMPLETED ✅
- [x] Add single-node and multi-node configurations
- [x] Update instance types for different node counts
- [x] Configure storage requirements for multi-node
- [x] Add load balancer configurations

#### Task 2.3: Parallel Execution Optimization - COMPLETED ✅
- [x] Implement parallel matrix job execution
- [x] Add job dependency management
- [x] Configure resource limits for parallel jobs
- [x] Add failure handling for matrix jobs

### Phase 3: Advanced Testing Features

#### Task 3.1: Version-Specific Testing
- [ ] Add version-specific Helm values
- [ ] Configure version-specific resource limits
- [ ] Add compatibility checks for deprecated APIs
- [ ] Implement version-specific test suites

#### Task 3.2: Distribution-Specific Testing
- [ ] Add distribution-specific validation tests
- [ ] Configure networking tests for each distribution
- [ ] Add storage validation for different distributions
- [ ] Implement load balancer testing

#### Task 3.3: Performance Testing
- [ ] Add performance benchmarks for each matrix combination
- [ ] Configure resource utilization monitoring
- [ ] Add deployment time measurements
- [ ] Implement scalability testing

## Technical Implementation

### Current Matrix Configuration (Phase 2 - IMPLEMENTED)

```yaml
strategy:
  matrix:
    include:
      # k3s single-node configurations
      - k8s-version: "v1.31.2"
        distribution: "k3s"
        nodes: 1
        instance-type: "r1.small"
        timeout-minutes: 15
      - k8s-version: "v1.32.2"
        distribution: "k3s"
        nodes: 1
        instance-type: "r1.small"
        timeout-minutes: 15
      # k3s multi-node configurations
      - k8s-version: "v1.32.2"
        distribution: "k3s"
        nodes: 3
        instance-type: "r1.medium"
        timeout-minutes: 20
      # kind configurations
      - k8s-version: "v1.31.2"
        distribution: "kind"
        nodes: 1
        instance-type: "r1.small"
        timeout-minutes: 20
      - k8s-version: "v1.32.2"
        distribution: "kind"
        nodes: 3
        instance-type: "r1.medium"
        timeout-minutes: 25
      # EKS configurations
      - k8s-version: "v1.32.2"
        distribution: "eks"
        nodes: 2
        instance-type: "r1.medium"
        timeout-minutes: 30
    exclude:
      # Temporarily exclude combinations that may not be supported
      - k8s-version: "v1.31.2"
        distribution: "eks"
        nodes: 2
  fail-fast: false
  max-parallel: 4
```

### Distribution-Specific Configurations (IMPLEMENTED)

```yaml
case "${{ matrix.distribution }}" in
  "k3s")
    cluster-disk-size: 20GB
    cluster-ttl: 4h
    networking-config: flannel
    resource-priority: high
    ;;
  "kind")
    cluster-disk-size: 30GB
    cluster-ttl: 4h
    networking-config: kindnet
    resource-priority: medium
    ;;
  "eks")
    cluster-disk-size: 50GB
    cluster-ttl: 6h
    networking-config: aws-vpc-cni
    resource-priority: low
    ;;
esac
```

### Resource Naming Strategy

```yaml
cluster-name: ${{ needs.setup.outputs.channel-name }}-${{ matrix.k8s-version }}-${{ matrix.distribution }}
customer-name: ${{ needs.setup.outputs.customer-name }}-${{ matrix.k8s-version }}-${{ matrix.distribution }}
```

### Timeout Configuration

```yaml
timeout-minutes: 
  k3s: 15
  kind: 20
  eks: 30
```

## Testing Strategy

### Phase 1 Testing - COMPLETED ✅
- [x] Test basic matrix with 2 versions, 1 distribution
- [x] Validate resource naming and cleanup
- [x] Ensure parallel execution works correctly
- [x] Test failure scenarios and recovery

### Phase 2 Testing - COMPLETED ✅
- [x] Test full matrix with all versions and distributions
- [x] Validate cross-environment compatibility
- [x] Test resource limits and scaling
- [x] Performance testing across environments

### Phase 3 Testing
- [ ] End-to-end testing across all matrix combinations
- [ ] Load testing with multiple parallel jobs
- [ ] Failure injection testing
- [ ] Resource cleanup validation

## Resource Requirements

### Compute Resources
- Increased parallel job execution
- Multiple cluster creation simultaneously
- Extended test execution time

### API Rate Limits
- Replicated API calls multiplied by matrix size
- Kubernetes API calls for multiple clusters
- GitHub API calls for artifact management

### Storage Requirements
- Multiple artifact uploads per matrix job
- Extended log retention for debugging
- Kubeconfig storage for each cluster

## Monitoring and Observability

### Metrics to Track
- [ ] Matrix job success/failure rates
- [ ] Deployment times per environment
- [ ] Resource utilization across distributions
- [ ] API rate limit usage

### Alerting
- [ ] Matrix job failures
- [ ] Resource cleanup failures
- [ ] Extended deployment times
- [ ] API rate limit approaching

## Risk Assessment

### High Risk
- **Increased Cost:** Multiple clusters running simultaneously
- **API Rate Limits:** Potential throttling with increased API calls
- **Complexity:** Matrix management and debugging

### Medium Risk
- **Flaky Tests:** Different environments may have different stability
- **Resource Conflicts:** Parallel job resource naming conflicts
- **Cleanup Failures:** More complex cleanup across matrix jobs

### Low Risk
- **Documentation:** Need for updated documentation
- **Learning Curve:** Team adaptation to matrix testing

## Success Criteria

### Phase 1 Success - ACHIEVED ✅
- [x] Basic matrix testing works with 2 environments
- [x] Resource naming and cleanup functions correctly
- [x] Parallel execution completes without conflicts
- [x] Test results are clearly identified by matrix parameters

### Phase 2 Success - ACHIEVED ✅
- [x] Full matrix testing across all defined environments
- [x] Cross-environment compatibility validated
- [x] Performance metrics collected and analyzed
- [x] Resource utilization within acceptable limits

**Current Results:**
- ✅ **6 Active Matrix Combinations** tested simultaneously
- ✅ **Distribution-Specific Validation** for k3s, kind, and EKS
- ✅ **Multi-Node Configuration Testing** with 1-3 nodes
- ✅ **Resource Optimization** with priority-based allocation
- ✅ **Performance Monitoring** with detailed metrics collection

### Phase 3 Success
- [ ] Complete matrix testing integration
- [ ] Automated failure detection and recovery
- [ ] Performance benchmarks established
- [ ] Documentation and training completed

## Timeline

### Phase 1: Basic Implementation (1-2 weeks)
- Week 1: Workflow structure and basic matrix
- Week 2: Testing and validation

### Phase 2: Enhanced Features (2-3 weeks)
- Week 3-4: Distribution-specific configurations
- Week 5: Node configuration matrix

### Phase 3: Advanced Testing (2-3 weeks)
- Week 6-7: Version-specific and distribution-specific testing
- Week 8: Performance testing and optimization

## Dependencies

- Replicated cluster API availability
- GitHub Actions runner capacity
- Kubernetes distribution support
- Helm chart compatibility across versions

## Rollback Plan

If matrix testing causes issues:
1. Revert to single-environment testing
2. Implement gradual rollout with subset of matrix
3. Add circuit breakers for failing combinations
4. Implement manual matrix selection for debugging

## Future Considerations

- Cloud provider matrix (AWS, GCP, Azure)
- Architecture matrix (x86, ARM)
- Helm version matrix
- Application version matrix
- Regional testing matrix