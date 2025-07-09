# CLAUDE.md for WG-Easy Helm Chart Development

This file contains common commands and workflows for working with the WG-Easy Helm chart project.

## Current Project Status

**Branch:** `adamancini/gh-actions`  
**Last Updated:** December 27, 2024

### Recent Changes
- Enhanced customer workflow with full test cycle and improved task documentation
- Updated Helm chart dependencies and fixed imagePullSecret template
- Added customer-helm-install task for deployment using replicated environment
- Implemented automatic name normalization for git branch names in cluster, customer, and channel creation
- Added comprehensive timeout and monitoring guidance for Helm operations
- Enhanced background monitoring capabilities for detecting early deployment failures

### Key Features
- **Automatic Name Normalization**: Git branch names are automatically normalized (replacing `/`, `_`, `.` with `-`) to match Replicated Vendor Portal backend slug format
- **Enhanced Customer Workflow**: Complete customer lifecycle management from creation to deployment
- **Improved Error Detection**: Background monitoring and early timeout detection for ImagePullBackOff scenarios
- **Multi-Registry Support**: Container images published to GHCR, Google Artifact Registry, and Replicated Registry
- **Comprehensive Testing**: Full test cycles with cluster creation, deployment, and cleanup automation

### Recent Improvements
- Enhanced Taskfile.yaml with automatic name normalization for cluster, customer, and channel operations
- Improved utils.yml with normalized customer name handling in license retrieval
- Updated documentation with comprehensive guidance for background monitoring and timeout detection
- Streamlined customer workflow commands to use git branch names directly
- **Optimized GitHub Actions workflows** with Task-based operations and reusable actions
- **Added chart validation tasks** for consistent linting and templating across environments
- **Implemented PR validation cycle** with automated cleanup and better error handling
- **Enhanced channel management** with unique channel ID support to avoid ambiguous channel names

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

##### Phase 2: Replace Custom Release Creation

**Task 2.1: Action Replacement**

- [ ] Replace `.github/actions/replicated-release` with `replicatedhq/replicated-actions/create-release@v1`
- [ ] Update workflow to pass chart directory and release parameters directly
- [ ] Remove `task channel-create` and `task release-create` dependencies

**Task 2.2: Workflow Integration**

- [ ] Modify `create-release` job in workflow to use official action
- [ ] Update job outputs to match official action format
- [ ] Test release creation functionality

**Benefits:**

- Official Replicated action with better error handling
- Direct API integration using JavaScript library (no CLI needed)
- Built-in airgap build support with configurable timeout
- Outputs channel-slug and release-sequence for downstream jobs

##### Phase 3: Replace Custom Customer and Cluster Management

**Task 3.1: Customer Management**

- [ ] Replace `task customer-create` with `replicatedhq/replicated-actions/create-customer@v1`
- [ ] Replace `task utils:get-customer-license` with customer action outputs
- [ ] Update workflow to capture customer-id and license-id outputs

**Task 3.2: Cluster Management**

- [ ] Replace `task cluster-create` with `replicatedhq/replicated-actions/create-cluster@v1`
- [ ] Replace `task cluster-delete` with `replicatedhq/replicated-actions/remove-cluster@v1`
- [ ] Update workflow to capture cluster-id and kubeconfig outputs
- [ ] Remove `task setup-kubeconfig` dependency

**Benefits:**

- Direct resource provisioning without Task wrapper
- Returns structured outputs (customer-id, license-id, cluster-id, kubeconfig)
- More granular configuration options
- Automatic kubeconfig export
- Better error handling and validation

##### Phase 4: Replace Test Deployment Action - STRATEGY REVISED

**Task 4.1: Decompose Custom Action**

- [ ] Break down `.github/actions/test-deployment` into individual workflow steps
- [ ] Use replicated-actions for resource creation (customer, cluster, channel, release)
- [ ] **PRESERVE** `task customer-helm-install` for helmfile-based deployment
- [ ] Remove complex composite action

**Task 4.2: Resource Management Integration**

- [ ] Use replicated-actions for customer/cluster/channel/release creation
- [ ] Pass outputs (license-id, cluster-id, kubeconfig) to `task customer-helm-install`
- [ ] **MAINTAIN** helmfile orchestration for multi-chart deployment
- [ ] Remove direct helm installation replacement strategy

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

**Milestone 2: Core Refactoring** - NEXT PRIORITY

- [ ] Replace release creation and customer/cluster management
- [ ] Migrate to official actions for core operations
- [ ] Reduce dependency on custom Task-based actions

**Milestone 3: Full Migration** - REVISED STRATEGY

- [ ] Complete test deployment refactoring (preserving helmfile)
- [ ] Implement enhanced cleanup process
- [ ] Remove remaining custom composite actions

**Milestone 4: Validation**

- [ ] End-to-end testing of refactored workflow
- [ ] Performance comparison with original implementation
- [ ] Documentation updates

#### Expected Outcomes

- **Immediate**: Restored CI functionality with proper CLI caching ✅ **ACHIEVED**
- **Short-term**: Reduced maintenance burden with official actions
- **Long-term**: Better reliability, improved visibility, and enhanced features
- **Eliminated**: CLI installation issues by using JavaScript library approach
- **Improved**: Consistent error handling across all operations
- **Preserved**: Helmfile orchestration for multi-chart deployments

#### Maintained Functionality

- **Task-based local development**: All existing Task commands remain functional
- **Backward compatibility**: Existing workflows continue to work during transition
- **Enhanced CI/CD**: Official actions provide better reliability and features
- **Hybrid approach**: Best of both worlds - Tasks for local dev, actions for CI

This refactoring addresses the immediate CLI installation failure while providing a long-term solution that leverages official Replicated actions for improved reliability and reduced maintenance burden.

## Additional Resources

- [Chart Structure Guide](docs/chart-structure.md)
- [Development Workflow](docs/development-workflow.md)
- [Task Reference](docs/task-reference.md)
- [Replicated Integration](docs/replicated-integration.md)
- [Example Patterns](docs/examples.md)
