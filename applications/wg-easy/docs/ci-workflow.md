# CI/CD Workflows

The wg-easy application has three GitHub Actions workflows that automate validation, image publishing, and resource cleanup. This document describes what each workflow does and how it fits into the development process.

For context on the local tooling (Task, Helmfile) that the CI workflows build on, see the [Tooling Guide](tooling-guide.md).

## Workflow Overview

| Workflow | File | Trigger | Purpose |
|---|---|---|---|
| [PR Validation](#pr-validation) | `wg-easy-pr-validation.yaml` | PR to `main` affecting `applications/wg-easy/` | Build, release, deploy, and test across a matrix of K8s versions |
| [Image CI](#image-ci) | `wg-easy-image.yml` | Push to `main`, tags, PRs affecting `applications/wg-easy/` | Build and publish the dev tools container to three registries |
| [PR Cleanup](#pr-cleanup) | `wg-easy-pr-cleanup.yaml` | PR closed | Delete test clusters, customers, and channels created by PR validation |

All workflow files live in `.github/workflows/`. Reusable composite actions live in `.github/actions/`.

## PR Validation

**File**: `.github/workflows/wg-easy-pr-validation.yaml`

This is the primary CI pipeline. It validates every pull request by running through the full lifecycle: chart validation, packaging, Replicated release creation, cluster provisioning, deployment, and testing.

### Job Sequence

```
setup
  └─► validate-charts
        └─► build-and-package
              └─► create-resources (channel, release, customer)
                    └─► create-clusters (matrix: k3s × 3 K8s versions)
                          └─► test-deployment (matrix: same)
```

Each job depends on the one above it. The matrix jobs (`create-clusters` and `test-deployment`) run in parallel across Kubernetes versions.

### What Each Job Does

**setup** -- Derives branch name, channel name, and customer name from the PR ref. Names are normalized (lowercased, `/` replaced with `-`) for Replicated and Kubernetes compatibility.

**validate-charts** -- Runs `task chart-validate` via the `chart-validate` composite action. This lints all charts, renders templates, and validates the helmfile configuration.

**build-and-package** -- Runs `task chart-package-all` via the `chart-package` composite action. Packages all charts and prepares the `release/` directory. Uploads the release artifacts for use by downstream jobs.

**create-resources** -- Creates (or reuses) the Replicated resources needed for deployment:
- **Channel**: Checks if a channel matching the branch name already exists; creates one if not
- **Release**: Uses `replicatedhq/replicated-actions/create-release` to upload the release artifacts and promote to the channel
- **Customer**: Checks for an existing customer; creates one with `replicatedhq/replicated-actions/create-customer` if not found

All resource creation is idempotent -- re-running the workflow on the same PR reuses existing resources rather than creating duplicates.

**create-clusters** -- Provisions test clusters using the Replicated CLI across a compatibility matrix. Each matrix entry specifies a Kubernetes version, distribution, node count, and instance type. Clusters are created in parallel.

**test-deployment** -- For each matrix entry, retrieves the cluster kubeconfig and runs:
1. `task customer-helm-install` -- deploys all charts via helmfile in the `replicated` environment (charts from OCI registry, image proxy enabled)
2. `task test` -- runs validation tests
3. Distribution-specific checks (node count, storage class, resource utilization)

### Compatibility Matrix

The matrix is defined in the `create-clusters` and `test-deployment` jobs. The current configuration tests across three K8s minor versions on k3s single-node clusters. The matrix is straightforward to extend with additional distributions (kind, EKS) or multi-node configurations.

### Concurrency

The workflow uses GitHub's `concurrency` setting to cancel in-progress runs when new commits are pushed to the same PR, preventing resource waste.

### Failure Handling

- Debug logs are uploaded as artifacts on failure
- Cluster creation includes retry logic and connectivity validation
- Kubeconfig retrieval has retry loops with backoff

## Image CI

**File**: `.github/workflows/wg-easy-image.yml`

Builds and publishes the `wg-easy-tools` development container image to three registries:

| Registry | Image |
|---|---|
| GitHub Container Registry | `ghcr.io/replicatedhq/platform-examples/wg-easy-tools` |
| Google Artifact Registry | `us-central1-docker.pkg.dev/replicated-qa/wg-easy/wg-easy-tools` |
| Replicated Registry | `registry.replicated.com/wg-easy-cre/wg-easy-tools` |

### How It Works

1. **build** -- Builds a multi-arch image (amd64 + arm64) without pushing. Uses GitHub Actions cache for layer reuse.
2. **push-ghcr**, **push-gar**, **push-replicated** -- Three parallel jobs, each authenticating to one registry and pushing the image with appropriate tags.

### Tagging Strategy

| Trigger | Tags applied |
|---|---|
| Push to `main` | `latest`, `sha-<commit>` |
| Tag push (`v*`) | Semver tags (`1.2.3`, `1.2`, `1`) |
| Feature branch | `<branch-name>`, `<branch-name>-sha-<commit>` |

## PR Cleanup

**File**: `.github/workflows/wg-easy-pr-cleanup.yaml`

Triggered when a PR is closed (merged or abandoned). Runs `task cleanup-pr-resources` to delete:

- Test clusters created for the PR
- Customer resources
- Channels and releases

Resources are identified by the normalized branch name. Cleanup logs are uploaded as artifacts with 3-day retention.

## Reusable Actions

The workflows share common setup through composite actions in `.github/actions/`:

| Action | Purpose |
|---|---|
| `setup-tools` | Installs Helm, Task, yq, kubectl, helmfile, and Replicated CLI with caching |
| `chart-validate` | Runs `task chart-validate` with dependency caching |
| `chart-package` | Runs `task chart-package-all` and verifies release contents |

These actions keep the workflow files focused on orchestration while centralizing tool setup and caching logic.

## Required Secrets and Variables

| Name | Type | Purpose |
|---|---|---|
| `WG_EASY_REPLICATED_API_TOKEN` | Secret | Replicated Vendor Portal API authentication |
| `WG_EASY_REPLICATED_APP` | Variable | Application slug (e.g., `wg-easy-cre`) |
| `GCP_SA_KEY` | Secret | Google Cloud service account for Artifact Registry |
| `GITHUB_TOKEN` | Built-in | GHCR authentication (automatic) |

## Local vs CI

The CI workflows use the same Task commands you use locally. The main differences:

- **Resource creation**: CI uses `replicatedhq/replicated-actions` (JavaScript-based, no CLI binary needed) for creating channels, releases, and customers. Locally you use `task release-create`, `task customer-create`, etc., which call the Replicated CLI.
- **Deployment**: Both CI and local use `task customer-helm-install`, which calls `helmfile sync` in the `replicated` environment.
- **Tool installation**: CI uses the `setup-tools` composite action with caching. Locally you install tools yourself or use `task dev:shell` for a containerized environment.

The underlying pattern is the same: validate charts, package them, create a release, deploy via helmfile, test.
