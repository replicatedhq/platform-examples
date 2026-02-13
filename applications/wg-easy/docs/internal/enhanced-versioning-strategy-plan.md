# Enhanced Versioning Strategy Plan

## Overview

This plan outlines the implementation of a more sophisticated versioning strategy for the wg-easy PR validation workflow. The current approach uses basic branch names and run numbers, but should adopt semantic versioning patterns similar to the replicated-actions reference workflow for better release tracking and management.

## Current State

**Current Versioning Approach:**
- Branch names used directly for channel naming
- Run numbers for customer uniqueness
- No semantic versioning for releases
- Basic normalization (lowercase, hyphen replacement)

**Current Workflow Context (Updated January 2025):**
- ✅ **Compatibility Matrix Testing** - Phase 2 Complete with 6 active matrix combinations
- ✅ **Advanced GitHub Actions Integration** - Official replicated-actions fully integrated
- ✅ **Idempotent Resource Management** - Comprehensive resource lifecycle management
- ✅ **Matrix-Based Testing** - Multi-distribution validation across k3s, kind, EKS

**Limitations:**
- No version semantics for releases
- Difficult to track version progression
- No correlation between branch changes and versions
- Limited release metadata
- No support for pre-release or build metadata
- No integration with matrix testing results in versioning

## Proposed Enhancement

### Semantic Versioning Strategy

Implement a comprehensive versioning strategy that includes:

1. **Base Version:** Semantic version from project metadata
2. **Branch Identifier:** Normalized branch name
3. **Build Metadata:** Run ID and attempt number
4. **Pre-release Suffix:** Development/PR indicators

**Format:** `{base-version}-{branch-identifier}.{run-id}.{run-attempt}`

**Example:** `0.1.0-feature-auth-fix.12345.1`

**Matrix Integration Enhancement:**
- **Matrix-Aware Versioning:** `{base-version}-{branch-identifier}.{run-id}.{matrix-id}`
- **Matrix Example:** `0.1.0-feature-auth-fix.12345.k3s-v1-32-2`
- **Multi-Environment Correlation:** Link versions to specific test environments

## Implementation Plan

### Phase 1: Basic Semantic Versioning

#### Task 1.1: Version Configuration
- [ ] Add base version configuration to workflow
- [ ] Define version increment rules
- [ ] Create version validation logic
- [ ] Add version environment variables

#### Task 1.2: Branch Identifier Enhancement
- [ ] Improve branch name normalization
- [ ] Add character length limits
- [ ] Handle special characters consistently
- [ ] Add branch type detection (feature, bugfix, hotfix)

#### Task 1.3: Build Metadata Integration
- [ ] Include GitHub run ID in version
- [ ] Add run attempt number
- [ ] Include commit SHA for traceability
- [ ] Add build timestamp

#### Task 1.4: Version Generation Logic
- [ ] Create version generation function
- [ ] Add version validation
- [ ] Implement version comparison logic
- [ ] Add version formatting utilities

### Phase 2: Advanced Version Management

#### Task 2.1: Pre-release Versioning
- [ ] Add pre-release identifiers (alpha, beta, rc)
- [ ] Implement pre-release progression
- [ ] Add pre-release validation
- [ ] Configure pre-release channel mapping

#### Task 2.2: Version Metadata
- [ ] Add version description/notes
- [ ] Include branch information
- [ ] Add author and timestamp metadata
- [ ] Include commit message summary

#### Task 2.3: Version Persistence
- [ ] Store version in workflow artifacts
- [ ] Add version to release notes
- [ ] Include version in deployment manifests
- [ ] Add version to application labels

### Phase 3: Version Lifecycle Management

#### Task 3.1: Version Promotion
- [ ] Implement version promotion workflow
- [ ] Add version approval process
- [ ] Configure automatic promotion rules
- [ ] Add version rollback capabilities

#### Task 3.2: Version Tracking
- [ ] Add version history tracking
- [ ] Implement version comparison
- [ ] Add version analytics
- [ ] Create version dashboard

#### Task 3.3: Version Cleanup
- [ ] Implement version retention policies
- [ ] Add version archiving
- [ ] Configure version cleanup automation
- [ ] Add version deprecation handling

## Technical Implementation

### Version Generation Function

```yaml
- name: Generate Version
  id: version
  run: |
    # Base version from project metadata
    BASE_VERSION="0.1.0"
    
    # Branch identifier (normalized)
    BRANCH_IDENTIFIER=$(echo "${{ github.head_ref || github.ref_name }}" | 
      tr '[:upper:]' '[:lower:]' | 
      sed 's/[^a-zA-Z0-9]/-/g' | 
      sed 's/--*/-/g' | 
      sed 's/^-\|-$//g' | 
      cut -c1-20)
    
    # Build metadata
    RUN_ID="${{ github.run_id }}"
    RUN_ATTEMPT="${{ github.run_attempt }}"
    
    # Generate full version
    FULL_VERSION="${BASE_VERSION}-${BRANCH_IDENTIFIER}.${RUN_ID}.${RUN_ATTEMPT}"
    
    echo "version=$FULL_VERSION" >> $GITHUB_OUTPUT
    echo "base-version=$BASE_VERSION" >> $GITHUB_OUTPUT
    echo "branch-identifier=$BRANCH_IDENTIFIER" >> $GITHUB_OUTPUT
    echo "build-metadata=${RUN_ID}.${RUN_ATTEMPT}" >> $GITHUB_OUTPUT
```

### Version Metadata Structure

```yaml
version-metadata:
  version: "0.1.0-feature-auth-fix.12345.1"
  base-version: "0.1.0"
  branch-identifier: "feature-auth-fix"
  build-metadata: "12345.1"
  pre-release: "dev"
  commit-sha: "abc123..."
  author: "developer@example.com"
  timestamp: "2024-01-15T10:30:00Z"
  branch: "feature/auth-fix"
  pr-number: "42"
```

### Channel Naming Strategy

```yaml
channel-name: |
  if [[ "${{ github.event_name }}" == "pull_request" ]]; then
    echo "pr-${{ github.event.number }}-${{ steps.version.outputs.branch-identifier }}"
  else
    echo "${{ steps.version.outputs.branch-identifier }}"
  fi
```

## Integration Points

### Workflow Updates

#### Task 1: Setup Job Enhancement
- [ ] Add version generation to setup job
- [ ] Update outputs to include version information
- [ ] Add version validation steps
- [ ] Include version in job names

#### Task 2: Release Creation Updates
- [ ] Use semantic version for release creation
- [ ] Add version to release notes
- [ ] Include version in artifact names
- [ ] Update channel naming with version

#### Task 3: Deployment Integration
- [ ] Add version labels to Kubernetes resources
- [ ] Include version in deployment manifests
- [ ] Add version to application configuration
- [ ] Update health checks with version info

#### Task 4: Testing Integration
- [ ] Add version to test artifacts
- [ ] Include version in test reports
- [ ] Add version validation tests
- [ ] Update test naming with version

## Version Validation

### Pre-deployment Validation
- [ ] Semantic version format validation
- [ ] Branch identifier validation
- [ ] Build metadata validation
- [ ] Version uniqueness check

### Post-deployment Validation
- [ ] Version consistency check
- [ ] Application version reporting
- [ ] Version metadata verification
- [ ] Version tracking validation

## Monitoring and Observability

### Version Metrics
- [ ] Version generation success rate
- [ ] Version validation failures
- [ ] Version promotion frequency
- [ ] Version rollback incidents

### Version Tracking
- [ ] Version deployment history
- [ ] Version performance metrics
- [ ] Version error rates
- [ ] Version usage analytics

## Configuration Management

### Version Configuration File

```yaml
# version.yaml
version:
  base: "0.1.0"
  increment: "patch"
  pre-release: "dev"
  build-metadata: true
  format: "{base}-{branch}.{build}"
  
branch-mapping:
  main: "stable"
  develop: "dev"
  feature/*: "feature"
  bugfix/*: "fix"
  hotfix/*: "hotfix"
  
validation:
  max-length: 50
  allowed-characters: "[a-zA-Z0-9.-]"
  required-fields: ["base", "branch", "build"]
```

### Environment-Specific Configuration

```yaml
environments:
  development:
    version-suffix: "-dev"
    retention-days: 7
    auto-promote: false
    
  staging:
    version-suffix: "-staging"
    retention-days: 14
    auto-promote: true
    
  production:
    version-suffix: ""
    retention-days: 90
    auto-promote: false
```

## Risk Assessment

### High Risk
- **Version Conflicts:** Multiple PRs with same version
- **Breaking Changes:** Version format changes breaking existing processes
- **Complexity:** Increased complexity in version management

### Medium Risk
- **Migration Issues:** Existing resources with old version format
- **Validation Failures:** Strict validation causing workflow failures
- **Performance Impact:** Version generation overhead

### Low Risk
- **Documentation:** Need for updated documentation
- **Training:** Team adaptation to new versioning
- **Tooling:** Updates to supporting tools

## Testing Strategy

### Unit Testing
- [ ] Version generation function tests
- [ ] Version validation tests
- [ ] Version comparison tests
- [ ] Version formatting tests

### Integration Testing
- [ ] End-to-end version workflow tests
- [ ] Version persistence tests
- [ ] Version promotion tests
- [ ] Version cleanup tests

### Performance Testing
- [ ] Version generation performance
- [ ] Version validation performance
- [ ] Version storage performance
- [ ] Version retrieval performance

## Success Criteria

### Phase 1 Success
- [ ] Semantic versioning implemented
- [ ] Version generation works consistently
- [ ] Version metadata properly populated
- [ ] Backward compatibility maintained

### Phase 2 Success
- [ ] Pre-release versioning functional
- [ ] Version metadata fully populated
- [ ] Version persistence working
- [ ] Version tracking operational

### Phase 3 Success
- [ ] Complete version lifecycle management
- [ ] Version promotion workflow functional
- [ ] Version analytics and reporting
- [ ] Documentation and training completed

## Timeline

### Phase 1: Basic Implementation (1-2 weeks)
- Week 1: Version generation and basic semantic versioning
- Week 2: Integration and testing

### Phase 2: Enhanced Features (2-3 weeks)
- Week 3-4: Pre-release versioning and metadata
- Week 5: Version persistence and tracking

### Phase 3: Advanced Management (2-3 weeks)
- Week 6-7: Version lifecycle management
- Week 8: Analytics and optimization

## Dependencies

- GitHub Actions workflow access
- Semantic versioning library/tools
- Version storage solution
- Monitoring and analytics tools

## Rollback Plan

If versioning enhancements cause issues:
1. Revert to simple branch-based naming
2. Implement gradual rollout with feature flags
3. Add version format fallbacks
4. Implement manual version override

## Future Considerations

- Integration with package managers (npm, helm)
- Automated version bumping based on changes
- Version compatibility matrix
- Multi-environment version tracking
- Version-based deployment strategies
- Integration with external version management tools