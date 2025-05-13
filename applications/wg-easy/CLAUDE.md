# CLAUDE.md for WG-Easy Helm Chart Development

This file contains common commands and workflows for working with the WG-Easy Helm chart project.

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

# Install all charts using Helmfile
task helm-install

# Run tests
task test

# Full test cycle (create cluster, deploy, test, delete)
task full-test-cycle
```

## Release Management

```bash
# Prepare release files
task release-prepare

# Create and promote a release
task release-create RELEASE_VERSION=x.y.z RELEASE_CHANNEL=Unstable

# Customer management
task customer-create CUSTOMER_NAME=example
task customer-ls
task customer-delete CUSTOMER_ID=your-customer-id
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
```

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

1. Create a customer if needed: `task customer-create CUSTOMER_NAME=test-customer`
2. Create a test cluster: `task cluster-create`
3. Set up kubeconfig: `task setup-kubeconfig`
4. Expose ports: `task cluster-ports-expose`
5. Deploy application: `task helm-install`
6. Run tests: `task test`
7. Clean up: `task cluster-delete`

## Additional Resources

- [Chart Structure Guide](docs/chart-structure.md)
- [Development Workflow](docs/development-workflow.md)
- [Task Reference](docs/task-reference.md)
- [Replicated Integration](docs/replicated-integration.md)
- [Example Patterns](docs/examples.md)