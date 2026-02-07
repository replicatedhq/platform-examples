# CLAUDE.md for WG-Easy Helm Chart Development

Common commands and workflows for working on the wg-easy project. See the [README](README.md) for the composable multi-chart architecture overview and the [implementation journal](docs/internal/implementation-journal.md) for project history.

## Key Architecture Notes

- **wg-easy chart** uses the [bjw-s/common library chart](https://github.com/bjw-s-labs/helm-charts/tree/main) to generate Kubernetes resources. Values schema: [values.yaml](https://github.com/bjw-s-labs/helm-charts/blob/main/charts/library/common/values.yaml), [values.schema.json](https://github.com/bjw-s-labs/helm-charts/blob/main/charts/library/common/values.schema.json)
- **templates chart** is imported as a dependency in Chart.yaml and generates common resources like Traefik routes
- **Per-chart `replicated/` directories** contain `config.yaml`, `helmChart-*.yaml`, and each chart's templates include `_supportbundle.tpl` and `_preflight.tpl`
- **Helmfile** (`helmfile.yaml.gotmpl`) orchestrates deployment order with `default` and `replicated` environments
- **`task release-prepare`** walks `charts/*/replicated/` to merge configs, set versions, and package charts

### Taskfile Development Guidelines

When developing or modifying tasks in the Taskfile:

**Important**: Always update the [task dependency graph](task-dependency-graph.md) when adding, removing, or changing task dependencies. The graph provides critical visibility into task relationships and workflow dependencies for both development and CI/CD operations.

## Development Environment Setup

```bash
task dev:start        # Start the development container
task dev:shell        # Get a shell in the development container
task dev:stop         # Stop the development container
task dev:build-image  # Rebuild the development container image
```

## Cluster Management

```bash
task cluster-create        # Create a test cluster (K3s by default)
task cluster-list          # Get information about the current cluster
task setup-kubeconfig      # Set up kubeconfig for the test cluster
task cluster-ports-expose  # Expose ports for the cluster
task cluster-delete        # Delete the test cluster
```

## Chart Development

```bash
task dependencies-update   # Update Helm dependencies for all charts
task chart-lint-all        # Lint all charts
task chart-template-all    # Template all charts for syntax validation
task chart-validate        # Complete validation (lint + template + helmfile)
task chart-package-all     # Package all charts for distribution
task helm-install          # Install all charts using Helmfile
task test                  # Run tests
task full-test-cycle       # Create cluster, deploy, test, delete
```

### Customer Workflow

```bash
# Use current git branch name as customer/cluster/channel names
# Names are automatically normalized (/, _, . replaced with -)
task customer-helm-install CUSTOMER_NAME=$(git branch --show-current) \
  CLUSTER_NAME=$(git branch --show-current) \
  REPLICATED_LICENSE_ID=xxx CHANNEL_ID=your-channel-id

task customer-full-test-cycle CUSTOMER_NAME=$(git branch --show-current) \
  CLUSTER_NAME=$(git branch --show-current)

task pr-validation-cycle BRANCH_NAME=$(git branch --show-current)
task cleanup-pr-resources BRANCH_NAME=$(git branch --show-current)
```

## Release Management

```bash
task release-prepare                                        # Package charts and merge configs
task release-create RELEASE_VERSION=x.y.z RELEASE_CHANNEL=Unstable

# Channel management
task channel-create RELEASE_CHANNEL=channel-name
task channel-delete RELEASE_CHANNEL_ID=channel-id

# Customer management
task customer-create CUSTOMER_NAME=$(git branch --show-current) RELEASE_CHANNEL_ID=your-channel-id
task customer-ls
task customer-delete CUSTOMER_ID=your-customer-id
```

## Customization Options

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

# Application configuration
APP_SLUG=wg-easy-cre

# Container registry options
DEV_CONTAINER_REGISTRY=ghcr.io  # Default: GitHub Container Registry
```

## Name Normalization

Customer, cluster, and channel names are automatically normalized by replacing `/`, `_`, `.` with `-`. This ensures compatibility with Replicated Vendor Portal slugs and Kubernetes DNS-1123 naming.

| Git Branch Name | Normalized Name |
|----------------|----------------|
| `feature/new-ui` | `feature-new-ui` |
| `user_story_123` | `user-story-123` |
| `v1.2.3` | `v1-2-3` |

## Claude Code Configuration

Timeout settings for long-running operations:

- `task helm-install`: 1200000ms (20 min) -- double the helmfile timeout of 600s
- `task full-test-cycle`: 1800000ms (30 min) -- accounts for cluster creation + deployment + testing
- `task cluster-create`: 600000ms (10 min) -- double typical cluster creation time

### Early Timeout Detection

During helm install operations, skip waiting for the full timeout if pods show `ImagePullBackOff` state. Use `kubectl get pods` to check status and terminate early if multiple pods show `ImagePullBackOff` or `ErrImagePull`.

### Background Monitoring

When running helm-install tasks, monitor for early failures:

```bash
kubectl get pods --all-namespaces | grep -E "(ImagePullBackOff|ErrImagePull|CrashLoopBackOff)"
```

Terminate early on: persistent `ImagePullBackOff`, `CrashLoopBackOff` across restarts, resource quota exceeded, PVC binding failures.

### Local Testing

When debugging, remove `atomic: true` from `helmfile.yaml.gotmpl` so failed resources persist for inspection. Clean up manually with `helm uninstall` after debugging.

## Container Registry

Images are published to three registries:

- **GHCR**: `ghcr.io/replicatedhq/platform-examples/wg-easy-tools`
- **Google Artifact Registry**: `us-central1-docker.pkg.dev/replicated-qa/wg-easy/wg-easy-tools`
- **Replicated Registry**: `registry.replicated.com/wg-easy-cre/image`

Required GitHub secrets: `GCP_SA_KEY`, `WG_EASY_REPLICATED_API_TOKEN`.

## Replicated Registry Proxy

In the `replicated` environment, helmfile automatically rewrites image URLs through the Replicated proxy:

- `ghcr.io/wg-easy/wg-easy` becomes `proxy.replicated.com/proxy/wg-easy-cre/ghcr.io/wg-easy/wg-easy`

Deployed automatically via `helmfile -e replicated apply`.

## GitHub Actions

The PR validation workflow uses official `replicatedhq/replicated-actions` for resource management (channels, customers, clusters, releases) while preserving helmfile-based deployment for multi-chart orchestration. See [CI Workflow](docs/ci-workflow.md) for details and [implementation journal](docs/internal/implementation-journal.md) for migration history.

## Additional Resources

- [Chart Structure Guide](docs/chart-structure.md)
- [Development Workflow](docs/development-workflow.md)
- [Task Reference](docs/task-reference.md)
- [Replicated Integration](docs/replicated-integration.md)
- [Example Patterns](docs/examples.md)
- [CI Workflow](docs/ci-workflow.md)
