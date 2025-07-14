# CLAUDE.md for WG-Easy Helm Chart Development

This file contains common commands and workflows for working with the WG-Easy Helm chart project.

## Current Project Status

**Branch:** `adamancini/replicated-actions`  
**Last Updated:** January 14, 2025

### Recent Changes
- **Workflow Analysis and Planning**: Completed comprehensive analysis of PR validation workflow compared to replicated-actions reference patterns
- **Planning Documentation**: Created detailed implementation plans for four key workflow enhancements
- **Enhanced GitHub Actions Integration**: Fully migrated to official replicated-actions for resource management (Phases 1-4 complete)
- **Improved Workflow Visibility**: Decomposed composite actions into individual workflow steps for better debugging
- **Performance Optimization Planning**: Developed comprehensive strategy for job parallelization and API call optimization
- **Version Management Planning**: Designed semantic versioning strategy for better release tracking

### Key Features
- **Modern GitHub Actions Architecture**: Fully migrated to official replicated-actions with individual workflow steps for better visibility
- **Idempotent Resource Management**: Sophisticated resource existence checking and reuse for reliable workflow execution
- **Enhanced Error Handling**: Comprehensive API error handling and validation across all operations
- **Multi-Registry Support**: Container images published to GHCR, Google Artifact Registry, and Replicated Registry
- **Comprehensive Testing**: Full test cycles with cluster creation, deployment, and cleanup automation
- **Automatic Name Normalization**: Git branch names automatically normalized for Replicated Vendor Portal and Kubernetes compatibility

### Recent Improvements
- **Complete GitHub Actions Modernization**: Replaced all custom composite actions with official replicated-actions
- **Workflow Visibility Enhancement**: Individual workflow steps replace complex composite actions for better debugging
- **Resource Management Optimization**: Direct API integration eliminates Task wrapper overhead
- **Enhanced Planning Documentation**: Created four comprehensive implementation plans for future workflow enhancements
- **Performance Analysis**: Identified optimization opportunities for job parallelization and API call reduction
- **Versioning Strategy**: Developed semantic versioning approach for better release tracking and management
- **Naming Consistency Planning**: Designed unified resource naming strategy for improved tracking and management

## Core Principles

The WG-Easy Helm Chart pattern is built on five fundamental principles:

### 1. Progressive Complexity

Start simple with individual chart validation and progressively move to more complex environments. This allows issues to be caught early when they are easier to fix.

- Begin with local chart validation
- Move to single chart deployments
- Progress to multi-chart integration
- Finally test in production-like environments

### 2. Fast Feedback Loops

Get immediate feedback at each development stage by automating testing and validation. This shortens the overall development cycle.

- Automated chart validation
- Quick cluster creation and deployment
- Standardized testing at each stage
- Fast iteration between changes

### 3. Reproducible Steps

Ensure consistent environments and processes across all stages of development, eliminating "works on my machine" issues.

- Consistent chart configurations
- Automated environment setup
- Deterministic dependency management
- Standardized deployment procedures

### 4. Modular Configuration

Allow different components to own their configuration independently, which can be merged at release time.

- Per-chart configuration files
- Automatic configuration merging
- Clear ownership boundaries
- Simplified collaborative development

### 5. Automation First

Use tools to automate repetitive tasks, reducing human error and increasing development velocity.

- Task-based workflow automation
- Helmfile for orchestration
- Automated validation and testing
- Streamlined release process

## Project Filesystem Layout

- `charts/` - Contains all Helm charts
  - `cert-manager/` - Wrapped cert-manager chart
  - `cert-manager-issuers/` - Chart for cert-manager issuers
  - `replicated-sdk/` - Replicated SDK chart
  - `templates/` - Common templates shared across charts
  - `traefik/` - Wrapped Traefik chart
  - `wg-easy/` - Main application chart
- `replicated/` - Root Replicated configuration
- `taskfiles/` - Task utility functions
- `helmfile.yaml.gotmpl` - Defines chart installation order
- `Taskfile.yaml` - Main task definitions

## Architecture Overview

Key components:

- **Taskfile**: Orchestrates the workflow with automated tasks
- **Helmfile**: Manages chart dependencies and installation order
- **Wrapped Charts**: Encapsulate upstream charts for consistency
- **Shared Templates**: Provide reusable components across charts
- **Replicated Integration**: Enables enterprise distribution

### Taskfile Development Guidelines

When developing or modifying tasks in the Taskfile:

⚠️ **Important**: Always update the [task dependency graph](task-dependency-graph.md) when adding, removing, or changing task dependencies. The graph provides critical visibility into task relationships and workflow dependencies for both development and CI/CD operations.

## `wg-easy` Chart

wg-easy uses the `bjw-s/common` [library chart](https://github.com/bjw-s-labs/helm-charts/tree/main) to generate Kubernetes resources. Library charts are commonly used to create DRY templates when authoring Helm charts.

Example values inputs to the bjw-s/common library chart are defined at https://github.com/bjw-s-labs/helm-charts/blob/main/charts/library/common/values.yaml and the schema for validation is defined at https://github.com/bjw-s-labs/helm-charts/blob/main/charts/library/common/values.schema.json

## `templates` Chart

The `templates` chart is imported as a dependency in Chart.yaml and is used to generate some common Kubernetes resources like Traefik routes.

## Development Environment Setup

```bash
# Start the development container
task dev:start

# Get a shell in the development container
task dev:shell

# Stop the development container
task dev:stop

# Rebuild the development container image
task dev:build-image
```

## Cluster Management

```bash
# Create a test cluster (K3s by default)
task cluster-create

# Get information about the current cluster
task cluster-list

# Set up kubeconfig for the test cluster
task setup-kubeconfig

# Expose ports for the cluster
task cluster-ports-expose

# Delete the test cluster
task cluster-delete
```

## Chart Development

```bash
# Update Helm dependencies for all charts
task dependencies-update

# Chart validation and linting
task chart-lint-all        # Lint all charts
task chart-template-all    # Template all charts for syntax validation
task chart-validate        # Complete validation (lint + template + helmfile)
task chart-package-all     # Package all charts for distribution

# Install all charts using Helmfile
task helm-install

# Install charts for a specific customer (requires pre-setup)
# By default, use current git branch name for customer, cluster, and channel names
# Note: names are automatically normalized (/, _, . replaced with -) by the tasks
# Use CHANNEL_ID for precise channel targeting or CHANNEL_SLUG for channel name
task customer-helm-install CUSTOMER_NAME=$(git branch --show-current) CLUSTER_NAME=$(git branch --show-current) REPLICATED_LICENSE_ID=xxx CHANNEL_ID=your-channel-id

# Run tests
task test

# Full test cycle (create cluster, deploy, test, delete)
task full-test-cycle

# Complete customer workflow (create cluster, customer, deploy, test, no cleanup)
# By default, use current git branch name for customer and cluster names
# Note: names are automatically normalized (/, _, . replaced with -) by the tasks
task customer-full-test-cycle CUSTOMER_NAME=$(git branch --show-current) CLUSTER_NAME=$(git branch --show-current)

# PR validation and cleanup
task pr-validation-cycle BRANCH_NAME=$(git branch --show-current)  # Complete PR validation workflow
task cleanup-pr-resources BRANCH_NAME=$(git branch --show-current) # Cleanup PR-related resources
```

## Release Management

```bash
# Prepare release files
task release-prepare

# Create and promote a release
task release-create RELEASE_VERSION=x.y.z RELEASE_CHANNEL=Unstable

# Channel management (returns channel ID for unique identification)
task channel-create RELEASE_CHANNEL=channel-name
task channel-delete RELEASE_CHANNEL_ID=channel-id

# Customer management
# By default, use current git branch name for customer name
# Note: names are automatically normalized (/, _, . replaced with -) by the tasks
# Use RELEASE_CHANNEL_ID for precise channel targeting or RELEASE_CHANNEL for channel name
task customer-create CUSTOMER_NAME=$(git branch --show-current) RELEASE_CHANNEL_ID=your-channel-id
task customer-ls
task customer-delete CUSTOMER_ID=your-customer-id
```

## Name Normalization

The WG-Easy workflow automatically normalizes customer, cluster, and channel names by replacing common git branch delimiters (`/`, `_`, `.`) with hyphens (`-`). This normalization serves two important purposes:

1. **Vendor Portal Backend Compatibility**: Cluster and channel slugs in the Replicated Vendor Portal backend use hyphenated naming conventions
2. **Kubernetes Naming Requirements**: Kubernetes resources require names that conform to DNS-1123 label standards

### Examples

| Git Branch Name | Normalized Name |
|----------------|----------------|
| `feature/new-ui` | `feature-new-ui` |
| `user_story_123` | `user-story-123` |
| `v1.2.3` | `v1-2-3` |
| `adamancini/gh-actions` | `adamancini-gh-actions` |

This means you can use git branch names directly in task commands without manual transformation:

```bash
# Works with any git branch name
task customer-create CUSTOMER_NAME=$(git branch --show-current)
task cluster-create CLUSTER_NAME=$(git branch --show-current)
```

## Customization Options

Common variables that can be overridden:

```bash
# Cluster configuration
CLUSTER_NAME=test-cluster
K8S_VERSION=1.32.2
DISK_SIZE=100
INSTANCE_TYPE=r1.small
DISTRIBUTION=k3s

# Release configuration
RELEASE_CHANNEL=Unstable
RELEASE_VERSION=0.0.1
RELEASE_NOTES="Release notes"

# Application configuration
APP_SLUG=wg-easy-cre

# Container registry options
DEV_CONTAINER_REGISTRY=ghcr.io  # Default: GitHub Container Registry
# For Google Artifact Registry:
# DEV_CONTAINER_REGISTRY=us-central1-docker.pkg.dev
# DEV_CONTAINER_IMAGE=replicated-qa/wg-easy/wg-easy-tools
```

## Claude Code Configuration

When using Claude Code with this repository, use these timeout settings for long-running operations:

- `task helm-install`: Use 1200000ms (20 minutes) timeout - double the helmfile timeout of 600s
- `task full-test-cycle`: Use 1800000ms (30 minutes) timeout - accounts for cluster creation + deployment + testing
- `task cluster-create`: Use 600000ms (10 minutes) timeout - double typical cluster creation time

Example: When running `task helm-install` via Bash tool, use `timeout: 1200000` parameter.

### Early Timeout Detection

During `helm install` or `helm-install` operations, you can skip waiting for the full timeout if pods end up in the `ImagePullBackOff` state. This indicates image pull failures that won't resolve by waiting longer. Use `kubectl get pods` to check pod status and terminate early if multiple pods show `ImagePullBackOff` or `ErrImagePull` states.

### Background Monitoring for Helm Operations

When running any task that calls `helm-install` (including `task helm-install`, `task customer-helm-install`, `task full-test-cycle`, and `task customer-full-test-cycle`), you can monitor the deployment in the background to detect early failures:

```bash
# In a separate terminal or background process, monitor pod status
watch kubectl get pods --all-namespaces

# Or check for specific error states
kubectl get pods --all-namespaces --field-selector=status.phase=Failed
kubectl get pods --all-namespaces | grep -E "(ImagePullBackOff|ErrImagePull|CrashLoopBackOff)"
```

Common failure patterns that indicate early termination should be considered:
- Multiple pods in `ImagePullBackOff` or `ErrImagePull` states
- Persistent `CrashLoopBackOff` across multiple restarts
- Resource quota exceeded errors
- Persistent volume claim binding failures

When these conditions are detected, the helm operation can be terminated early rather than waiting for the full timeout period.

### Local Testing Configuration

When testing Helm installations locally (including with helmfile), avoid using the `--atomic` flag so that failed resources remain in the cluster for debugging:

- Remove `atomic: true` from helmfile.yaml.gotmpl during debugging sessions
- Use `helm install` without `--atomic` for manual testing
- Failed pods and resources will persist, allowing inspection with `kubectl describe` and `kubectl logs`
- Clean up manually with `helm uninstall` after debugging is complete

## Common Workflows

### Local Development

1. Start development container: `task dev:start`
2. Get a shell in the container: `task dev:shell`
3. Create a test cluster: `task cluster-create`
4. Set up kubeconfig: `task setup-kubeconfig`
5. Update dependencies: `task dependencies-update`
6. Deploy charts: `task helm-install`
7. Run tests: `task test`
8. Clean up: `task cluster-delete`

### Creating a Release

1. Update chart versions in respective `Chart.yaml` files
2. Prepare release files: `task release-prepare`
3. Create and promote release: `task release-create RELEASE_VERSION=x.y.z RELEASE_CHANNEL=Unstable`

### Testing a Release

#### Option 1: Complete Customer Workflow

```bash
# Use current git branch name as default for customer and cluster names
# Note: names are automatically normalized (/, _, . replaced with -) by the tasks
task customer-full-test-cycle CUSTOMER_NAME=$(git branch --show-current) CLUSTER_NAME=$(git branch --show-current)
```

#### Option 2: Manual Step-by-Step

1. Create a customer if needed: `task customer-create CUSTOMER_NAME=$(git branch --show-current)`
2. Create a test cluster: `task cluster-create`
3. Set up kubeconfig: `task setup-kubeconfig`
4. Expose ports: `task cluster-ports-expose`
5. Deploy application: `task customer-helm-install CUSTOMER_NAME=$(git branch --show-current) CLUSTER_NAME=$(git branch --show-current) REPLICATED_LICENSE_ID=xxx CHANNEL_SLUG=$(git branch --show-current)`
6. Run tests: `task test`
7. Clean up: `task cluster-delete`

**Note:** All customer, cluster, and channel names are automatically normalized by replacing `/`, `_`, and `.` characters with `-` to match how slugs are represented in the Replicated Vendor Portal backend and ensure compatibility with Kubernetes naming requirements.

## Container Registry Setup

The WG-Easy Image CI workflow publishes container images to three registries for maximum availability:
- **GitHub Container Registry (GHCR)**: `ghcr.io/replicatedhq/platform-examples/wg-easy-tools`
- **Google Artifact Registry (GAR)**: `us-central1-docker.pkg.dev/replicated-qa/wg-easy/wg-easy-tools`
- **Replicated Registry**: `registry.replicated.com/wg-easy-cre/image`

### Required Secrets

To enable multi-registry publishing, add these GitHub repository secrets:

- `GCP_SA_KEY`: Service account JSON key with Artifact Registry Writer permissions
- `WG_EASY_REPLICATED_API_TOKEN`: Replicated vendor portal API token

### Google Cloud Setup

1. Create Artifact Registry repository:

```bash
gcloud artifacts repositories create wg-easy \
  --repository-format=docker \
  --location=us-central1 \
  --project=replicated-qa
```

2. Create service account with permissions:

```bash
gcloud iam service-accounts create github-actions-wg-easy \
  --project=replicated-qa

gcloud projects add-iam-policy-binding replicated-qa \
  --member="serviceAccount:github-actions-wg-easy@replicated-qa.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud iam service-accounts keys create sa-key.json \
  --iam-account=github-actions-wg-easy@replicated-qa.iam.gserviceaccount.com
```

3. Add the `sa-key.json` content as `GCP_SA_KEY` secret in GitHub repository settings.

### Replicated Registry Setup

1. Get your Replicated API Token from the vendor portal
2. Add `WG_EASY_REPLICATED_API_TOKEN` as a GitHub repository secret
3. The workflow automatically uses the `replicated` CLI to authenticate with `registry.replicated.com`

### Using Google Artifact Registry Images

To use GAR images instead of GHCR:

```bash
# Set registry to GAR
DEV_CONTAINER_REGISTRY=us-central1-docker.pkg.dev
DEV_CONTAINER_IMAGE=replicated-qa/wg-easy/wg-easy-tools

# Use GAR image
task dev:start
```

## Replicated Registry Proxy

When deploying in the `replicated` environment, the helmfile automatically configures all container images to use the Replicated Registry proxy for improved performance and reliability.

### Proxy Configuration

The proxy automatically rewrites image URLs following this pattern:

- **Original**: `ghcr.io/wg-easy/wg-easy:14.0`
- **Proxy**: `proxy.replicated.com/proxy/wg-easy-cre/ghcr.io/wg-easy/wg-easy:14.0`

### Supported Images

The following images are automatically proxied in the `replicated` environment:

- **WG-Easy**: `ghcr.io/wg-easy/wg-easy` → `proxy.replicated.com/proxy/wg-easy-cre/ghcr.io/wg-easy/wg-easy`
- **Traefik**: `docker.io/traefik/traefik` → `proxy.replicated.com/proxy/wg-easy-cre/docker.io/traefik/traefik`
- **Cert-Manager**: `quay.io/jetstack/cert-manager-*` → `proxy.replicated.com/proxy/wg-easy-cre/quay.io/jetstack/cert-manager-*`

### Usage

The proxy configuration is automatically applied when using the `replicated` environment:

```bash
# Deploy with proxy (replicated environment)
helmfile -e replicated apply

# Deploy without proxy (default environment)
helmfile apply
```

## GitHub Actions Integration

The project includes optimized GitHub Actions workflows that leverage the Task-based architecture:

### PR Validation Workflow
The `wg-easy-pr-validation.yaml` workflow is structured for maximum efficiency:

1. **Chart Validation** - Uses `task chart-validate` via reusable action
2. **Chart Packaging** - Builds once, shares artifacts between jobs  
3. **Release Creation** - Creates Replicated channel and release
4. **Deployment Testing** - Tests full customer workflow
5. **Automatic Cleanup** - Cleans up PR resources

### Reusable Actions
Located in `.github/actions/` for consistent tool setup and operations:

- **setup-tools** - Enhanced with improved caching for tools and dependencies
- **chart-validate** - Validates charts using `task chart-validate`
- **chart-package** - Packages charts using `task chart-package-all`
- **replicated-release** - Creates channels and releases using tasks
- **test-deployment** - Complete deployment testing workflow

### Benefits of Task Integration
- **Consistency** - Same operations work locally and in CI
- **Reduced Duplication** - Charts built once, shared via artifacts
- **Better Caching** - Helm dependencies and tools cached effectively
- **Maintainability** - Logic centralized in Taskfile, not scattered in YAML

### Idempotent Resource Management

The PR validation workflow now includes idempotent resource creation that checks for existing resources before creating new ones:

#### Channel Creation
- Checks if channel exists using Replicated API before creating
- Reuses existing channel if found, ensuring consistent channel-slug outputs
- Handles both new and existing channels transparently

#### Customer Creation  
- Uses unique customer names with workflow run number to prevent duplicates
- Queries existing customers by name before creating new ones
- When multiple customers exist with same name, selects most recently created
- Retrieves license ID from existing customer if found
- Creates new customer only when no matching customer exists

#### Cluster Creation
- Checks for existing clusters by name and excludes terminated clusters
- Exports kubeconfig for existing clusters automatically
- Creates new cluster only when no active cluster exists

#### Benefits
- **Workflow Reliability**: Multiple runs of the same PR don't fail due to resource conflicts
- **Cost Efficiency**: Reuses existing cluster resources instead of creating duplicates
- **Consistent Outputs**: All resource IDs and configurations remain consistent across runs
- **Reduced API Calls**: Minimizes unnecessary resource creation API calls

### Usage
PR validation runs automatically on pull requests affecting `applications/wg-easy/`. Manual trigger available via `workflow_dispatch`.

## Future Considerations

### Critical Issue: Replicated CLI Installation Failure - RESOLVED

**Previous Problem**: The GitHub Actions workflow was failing due to Replicated CLI installation issues in the `utils:install-replicated-cli` task. The task made unauthenticated GitHub API calls to download the CLI, which were getting rate-limited in CI environments.

**Root Cause Identified**:

- The CLI installation was not properly cached (only `~/.replicated` config was cached, not `/usr/local/bin/replicated`)
- Unauthenticated GitHub API calls hit rate limits
- Each CI run downloaded the CLI again instead of using cached version

**Resolution Implemented** (Phase 1 Complete):

✅ **CLI Installation Fixed**: Updated `.github/actions/setup-tools/action.yml` to include `/usr/local/bin/replicated` in cache path
✅ **GitHub Token Authentication**: Added GitHub token authentication to API calls in `taskfiles/utils.yml`
✅ **CI Pipeline Restored**: Tested and validated that current workflow works properly with improved caching

### Refactoring PR Validation Workflow Using Replicated Actions

The current GitHub Actions workflow uses custom composite actions that wrap Task-based operations. The [replicated-actions](https://github.com/replicatedhq/replicated-actions) repository provides official actions that could replace several of these custom implementations for improved reliability and reduced maintenance burden.

**Source Code Location**: The replicated-actions source code is located at https://github.com/replicatedhq/replicated-actions

**Reference Workflows**: Example workflows demonstrating replicated-actions usage patterns can be found at https://github.com/replicatedhq/replicated-actions/tree/main/example-workflows

#### Current State Analysis

The current workflow uses custom composite actions:

- `./.github/actions/replicated-release` (uses Task + Replicated CLI) - **FAILING DUE TO CLI INSTALL**
- `./.github/actions/test-deployment` (complex composite with multiple Task calls) - **FAILING DUE TO CLI INSTALL**
- Custom cluster and customer management via Task wrappers

**Key Discovery**: The `replicated-actions` use the `replicated-lib` NPM package (v0.0.1-beta.21) instead of the CLI binary, which eliminates the need for CLI installation entirely.

#### Comprehensive Refactoring Plan

##### Phase 1: Immediate CLI Installation Fix - COMPLETED ✅

**Task 1.1: Fix CLI Caching** - COMPLETED ✅

- [x] Update `.github/actions/setup-tools/action.yml` cache path to include `/usr/local/bin/replicated`
- [x] Add GitHub token authentication to `taskfiles/utils.yml` CLI download
- [x] Test CI pipeline with improved caching

**Task 1.2: Alternative - Direct CLI Installation** - COMPLETED ✅

- [x] Install Replicated CLI directly in setup-tools action (similar to yq, helmfile)
- [x] Remove dependency on `task utils:install-replicated-cli`
- [x] Use fixed version URL instead of GitHub API lookup

##### Phase 2: Replace Custom Release Creation - COMPLETED ✅

**Task 2.1: Action Replacement** - COMPLETED ✅

- [x] Replace `.github/actions/replicated-release` with `replicatedhq/replicated-actions/create-release@v1.19.0`
- [x] Update workflow to pass release directory and parameters directly using `yaml-dir` parameter
- [x] Remove `task channel-create` and `task release-create` dependencies

**Task 2.2: Workflow Integration** - COMPLETED ✅

- [x] Modify `create-release` job in workflow to use official action
- [x] Update job outputs to match official action format (`channel-slug`, `release-sequence`)
- [x] Test release creation functionality and validate successful integration
- [x] Fix parameter issue (changed from `chart:` to `yaml-dir:` for directory-based releases)

**Benefits Achieved:**

- Official Replicated action with better error handling
- Direct API integration using JavaScript library (no CLI needed)
- Built-in airgap build support with configurable timeout
- Outputs channel-slug and release-sequence for downstream jobs
- Eliminated CLI installation dependency completely
- Improved performance: create-release job completes in 14s with better reliability

##### Phase 3: Replace Custom Customer and Cluster Management - COMPLETED ✅

**Task 3.1: Customer Management** - COMPLETED ✅

- [x] Replace `task customer-create` with `replicatedhq/replicated-actions/create-customer@v1.19.0`
- [x] Replace `task utils:get-customer-license` with customer action outputs
- [x] Update workflow to capture customer-id and license-id outputs
- [x] Add channel-slug conversion logic for channel-id compatibility

**Task 3.2: Cluster Management** - COMPLETED ✅

- [x] Replace `task cluster-create` with `replicatedhq/replicated-actions/create-cluster@v1.19.0`
- [x] Update workflow to capture cluster-id and kubeconfig outputs
- [x] Remove `task setup-kubeconfig` dependency (kubeconfig automatically exported)
- [x] Maintain `cluster-ports-expose` for port configuration
- [ ] Replace `task cluster-delete` with `replicatedhq/replicated-actions/remove-cluster@v1` (Phase 5)

**Benefits Achieved:**

- Direct resource provisioning without Task wrapper
- Returns structured outputs (customer-id, license-id, cluster-id, kubeconfig)
- More granular configuration options
- Automatic kubeconfig export
- Better error handling and validation
- Eliminated 4 Task wrapper steps (customer-create, get-customer-license, cluster-create, setup-kubeconfig)
- Intelligent channel parameter handling (channel-id → channel-slug conversion)

##### Phase 4: Replace Test Deployment Action - COMPLETED ✅

**Task 4.1: Decompose Custom Action** - COMPLETED ✅

- [x] Break down `.github/actions/test-deployment` into individual workflow steps
- [x] Use replicated-actions for resource creation (customer, cluster, channel, release)
- [x] **PRESERVE** `task customer-helm-install` for helmfile-based deployment
- [x] Remove complex composite action

**Task 4.2: Resource Management Integration** - COMPLETED ✅

- [x] Use replicated-actions for customer/cluster/channel/release creation
- [x] Pass outputs (license-id, cluster-id, kubeconfig) to `task customer-helm-install`
- [x] **MAINTAIN** helmfile orchestration for multi-chart deployment
- [x] Remove direct helm installation replacement strategy

**Critical Constraint**: The `customer-helm-install` task must continue using helmfile for orchestrated multi-chart deployments with complex dependency management, environment-specific configurations, and registry proxy support. Individual helm chart deployments via replicated-actions cannot replace this functionality.

**Benefits:**

- Reduced complexity and maintenance burden for resource management
- Better visibility in GitHub Actions UI
- Easier debugging and monitoring
- Consistent error handling across all operations
- **Preserved** helmfile orchestration architecture

##### Phase 5: Enhanced Cleanup Process

**Task 5.1: Cleanup Refactoring**

- [ ] Replace `task cleanup-pr-resources` with individual replicated-actions
- [ ] Use `replicatedhq/replicated-actions/archive-customer@v1`
- [ ] Use `replicatedhq/replicated-actions/remove-cluster@v1`
- [ ] Implement parallel cleanup using job matrices

**Task 5.2: Error Handling**

- [ ] Add proper error handling for cleanup failures
- [ ] Test resource cleanup functionality
- [ ] Add resource tracking via action outputs

**Benefits:**

- More reliable cleanup using official actions
- Better resource tracking via action outputs
- Parallel cleanup operations possible

#### Implementation Strategy

**Milestone 1: Critical Fix** - COMPLETED ✅

- [x] Fix CLI installation to restore CI functionality
- [x] Test and validate current workflow works properly

**Milestone 2: Core Refactoring** - COMPLETED ✅

- [x] Replace release creation with official action (Phase 2 Complete)
- [x] Replace customer/cluster management with official actions (Phase 3 Complete)
- [x] Reduce dependency on custom Task-based actions (Major reduction achieved)

**Milestone 3: Full Migration** - COMPLETED ✅

- [x] Complete test deployment refactoring (preserving helmfile)
- [ ] Implement enhanced cleanup process
- [ ] Remove remaining custom composite actions

**Milestone 4: Validation**

- [ ] End-to-end testing of refactored workflow
- [ ] Performance comparison with original implementation
- [ ] Documentation updates

#### Expected Outcomes

- **Immediate**: Restored CI functionality with proper CLI caching ✅ **ACHIEVED**
- **Phase 2**: Replace release creation with official action ✅ **ACHIEVED**
- **Phase 3**: Replace customer/cluster management with official actions ✅ **ACHIEVED**
- **Phase 4**: Decompose test deployment composite action ✅ **ACHIEVED**
- **Short-term**: Reduced maintenance burden with official actions ✅ **ACHIEVED**
- **Long-term**: Better reliability, improved visibility, and enhanced features
- **Eliminated**: CLI installation issues by using JavaScript library approach
- **Improved**: Consistent error handling across all operations
- **Preserved**: Helmfile orchestration for multi-chart deployments

#### Phase 2 Results Summary

**Successfully Completed (December 2024):**

- ✅ **Official Action Integration**: Replaced custom `.github/actions/replicated-release` with `replicatedhq/replicated-actions/create-release@v1.19.0`
- ✅ **Parameter Optimization**: Fixed directory-based release handling by using `yaml-dir` parameter instead of `chart`
- ✅ **Output Standardization**: Updated workflow to use official action outputs (`channel-slug`, `release-sequence`)
- ✅ **Backward Compatibility**: Enhanced `test-deployment` action to support both `channel-id` and `channel-slug` parameters
- ✅ **Performance Improvement**: Create-release job now completes in 14s with better reliability
- ✅ **Validation**: Successfully tested end-to-end workflow in PR validation pipeline

**Key Technical Changes:**

- Eliminated dependency on `task channel-create` and `task release-create`
- Direct API integration via JavaScript library instead of CLI binary
- Enhanced error handling and validation through official action
- Maintained compatibility with existing Task-based deployment system

#### Phase 3 Results Summary

**Successfully Completed (December 2024):**

- ✅ **Customer Management Modernization**: Replaced `task customer-create` with `replicatedhq/replicated-actions/create-customer@v1.19.0`
- ✅ **Cluster Management Modernization**: Replaced `task cluster-create` with `replicatedhq/replicated-actions/create-cluster@v1.19.0`
- ✅ **Channel Compatibility**: Added intelligent channel-slug conversion logic for channel-id compatibility
- ✅ **Output Optimization**: Enhanced action outputs with customer-id, license-id, and cluster-id
- ✅ **Dependency Elimination**: Removed 4 Task wrapper steps (customer-create, get-customer-license, cluster-create, setup-kubeconfig)
- ✅ **Automatic Configuration**: Kubeconfig and license handling now built-in to official actions

**Key Technical Improvements:**

- Direct resource provisioning without Task wrapper overhead
- Structured outputs for better resource tracking and debugging
- Automatic kubeconfig export eliminates manual configuration steps
- Better error handling and validation through official actions
- Faster resource creation with direct API calls
- Enhanced compatibility with multiple channel parameter formats

#### Phase 4 Results Summary

**Successfully Completed (January 2025):**

- ✅ **Composite Action Decomposition**: Replaced `.github/actions/test-deployment` with individual workflow steps
- ✅ **Workflow Visibility**: Each step now shows individual progress in GitHub Actions UI
- ✅ **Resource Management**: Direct use of replicated-actions for customer and cluster creation
- ✅ **Helmfile Preservation**: Maintained `task customer-helm-install` for multi-chart orchestration
- ✅ **Timeout Configuration**: Added appropriate timeouts for deployment (20 minutes) and testing (10 minutes)
- ✅ **Output Management**: Preserved customer-id, license-id, and cluster-id outputs for downstream jobs
- ✅ **Action Deprecation**: Marked old composite action as deprecated with clear migration guidance

**Key Technical Improvements:**

- Individual workflow steps replace complex composite action
- Better error isolation and debugging capabilities
- Direct resource creation without composite action overhead
- Preserved helmfile orchestration for multi-chart deployments
- Maintained all existing functionality while improving visibility
- Enhanced timeout handling for long-running operations

#### Maintained Functionality

- **Task-based local development**: All existing Task commands remain functional
- **Backward compatibility**: Existing workflows continue to work during transition
- **Enhanced CI/CD**: Official actions provide better reliability and features
- **Hybrid approach**: Best of both worlds - Tasks for local dev, actions for CI

This refactoring addresses the immediate CLI installation failure while providing a long-term solution that leverages official Replicated actions for improved reliability and reduced maintenance burden.

## Planned Workflow Enhancements

Following a comprehensive analysis of the current PR validation workflow against the replicated-actions reference patterns, four key enhancement opportunities have been identified and documented:

### 1. Compatibility Matrix Testing Enhancement
**Status:** Phase 2 Complete - IMPLEMENTED ✅  
**Priority:** High  
**Documentation:** [Compatibility Matrix Testing Plan](docs/compatibility-matrix-testing-plan.md)

**Overview:** Implement multi-environment testing across different Kubernetes versions and distributions to ensure broad compatibility.

**Key Benefits:**
- Validate compatibility across multiple Kubernetes versions (v1.31.2, v1.32.2)
- Test against different distributions (k3s, kind, EKS)
- Parallel matrix job execution for faster feedback
- Multi-node configuration testing

**Implementation Phases:**
1. **Phase 1:** Basic matrix implementation with 2 versions, 1 distribution - COMPLETED ✅
2. **Phase 2:** Enhanced matrix with distribution-specific configurations - COMPLETED ✅
3. **Phase 3:** Advanced testing with performance benchmarks and multi-node support - PENDING

**Current Implementation Status:**
- ✅ **6 Active Matrix Combinations** across 3 distributions and 2 K8s versions
- ✅ **Multi-Distribution Testing** (k3s, kind, EKS) with specific configurations
- ✅ **Node Configuration Matrix** (1, 2, 3 nodes) with appropriate instance types
- ✅ **Distribution-Specific Validation** for networking and storage
- ✅ **Parallel Execution Optimization** with resource-aware limits
- ✅ **Performance Monitoring** and resource utilization tracking

### 2. Enhanced Versioning Strategy
**Status:** Planning Phase  
**Priority:** High  
**Documentation:** [Enhanced Versioning Strategy Plan](docs/enhanced-versioning-strategy-plan.md)

**Overview:** Implement semantic versioning strategy inspired by replicated-actions reference workflow for better release tracking and management.

**Key Benefits:**
- Semantic versioning format: `{base-version}-{branch-identifier}.{run-id}.{run-attempt}`
- Improved release tracking and correlation
- Version metadata integration
- Pre-release and build metadata support

**Implementation Phases:**
1. **Phase 1:** Basic semantic versioning with branch identifiers
2. **Phase 2:** Advanced version management with pre-release and metadata
3. **Phase 3:** Version lifecycle management with promotion and analytics

### 3. Performance Optimizations
**Status:** Planning Phase  
**Priority:** Medium  
**Documentation:** [Performance Optimizations Plan](docs/performance-optimizations-plan.md)

**Overview:** Optimize workflow performance through job parallelization, API call reduction, and enhanced caching strategies.

**Key Benefits:**
- Job parallelization to reduce sequential dependencies
- API call batching and optimization
- Enhanced caching for tools and dependencies
- Resource allocation optimization

**Implementation Phases:**
1. **Phase 1:** Job parallelization with dependency optimization
2. **Phase 2:** API call optimization and rate limit management
3. **Phase 3:** Caching strategy enhancement and resource efficiency
4. **Phase 4:** Advanced resource optimization and monitoring

### 4. Resource Naming Consistency
**Status:** Planning Phase  
**Priority:** Medium  
**Documentation:** [Resource Naming Consistency Plan](docs/resource-naming-consistency-plan.md)

**Overview:** Implement unified resource naming strategy for improved tracking and management across all workflow resources.

**Key Benefits:**
- Consistent naming format: `{prefix}-{normalized-branch}-{resource-type}-{run-id}`
- Improved resource correlation and tracking
- Standardized normalization rules
- Enhanced debugging and management capabilities

**Implementation Phases:**
1. **Phase 1:** Naming convention definition and validation
2. **Phase 2:** Implementation with centralized naming functions
3. **Phase 3:** Advanced features with templates and analytics

### Implementation Priority

**Completed (High Priority):**
- ✅ **Compatibility Matrix Testing** - Phase 2 Complete - Multi-environment testing implemented with 6 active matrix combinations

**Next (High Priority):**
- Enhanced Versioning Strategy - Improves release management
- Compatibility Matrix Testing Phase 3 - Advanced performance benchmarks

**Medium Term (Medium Priority):**
- Performance Optimizations - Reduces workflow execution time
- Resource Naming Consistency - Improves operational efficiency

### Current Workflow Status

The existing PR validation workflow is already more sophisticated than the replicated-actions reference in most areas, featuring:

- ✅ **Compatibility Matrix Testing** - Multi-environment validation across 6 combinations
- ✅ **Idempotent resource management** with existence checking
- ✅ **Official replicated-actions integration** for reliability
- ✅ **Comprehensive error handling** and validation
- ✅ **Advanced resource cleanup** with dedicated workflow
- ✅ **Modern GitHub Actions architecture** with individual workflow steps

The planned enhancements will build upon this strong foundation to provide additional testing coverage, improved performance, and better operational management.

## Additional Resources

- [Chart Structure Guide](docs/chart-structure.md)
- [Development Workflow](docs/development-workflow.md)
- [Task Reference](docs/task-reference.md)
- [Replicated Integration](docs/replicated-integration.md)
- [Example Patterns](docs/examples.md)
- [Phase 4 Implementation Plan](docs/phase-4-implementation-plan.md) - Detailed plan for test deployment action refactoring
