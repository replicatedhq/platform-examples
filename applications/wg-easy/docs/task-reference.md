# Task Reference

> This page is a command reference for the Task-based workflow. For an introduction to why Task and Helmfile were chosen over Make and plain Helm CLI, and how to translate these commands to your own tooling, see the [Tooling Guide](tooling-guide.md).

This document provides a concise reference for the tasks available in the WG-Easy Helm chart development pattern, organized by their purpose in the development workflow.

## Task Control Options

All tasks are configured to run in silent mode by default, showing only essential output. You can control the verbosity level using Task's built-in flags:

| Flag | Description | Example |
|------|-------------|---------|
| `--verbose` or `-v` | Show detailed task execution information including commands being run | `task -v cluster-create` |
| `--silent` or `-s` | Suppress all output except errors | `task -s dependencies-update` |
| (default) | Silent mode - shows command output but not task execution details | `task cluster-create` |

### Verbose Mode Examples

**Development and Debugging:**
```bash
# See detailed cluster creation process
task -v cluster-create

# Debug helm installation issues
task -v helm-install

# Watch full test cycle execution
task -v full-test-cycle
```

**Production Use:**
```bash
# Suppress all output for automation
task -s release-prepare

# Standard output for CI/CD
task release-create
```

## Development Tasks

These tasks support the iterative development process, focusing on fast feedback loops.

| Task | Description | Related Workflow Stage |
|------|-------------|------------------------|
| `dependencies-update` | Updates Helm dependencies for all charts in the repository | Stage 1: Dependencies |
| `helm-preflight` | Runs preflight checks on Helm charts using the preflight CLI | Stage 4: Validation |
| `helm-install` | Installs all charts using helmfile with proper sequencing | Stage 5: Integration Testing |
| `ports-expose` | Exposes the configured ports on the cluster for testing | Stage 4-5: Chart Installation/Integration |
| `remove-k3s-traefik` | Removes pre-installed Traefik from k3s clusters to avoid conflicts | Stage 4-5: Chart Installation/Integration |

### Common Development Combinations

**Complete Update and Deploy:**
```bash
task update-dependencies && task helm-install
```

**Single Chart Testing:**
```bash
helm dependency update ./charts/traefik
helm install traefik ./charts/traefik -n traefik --create-namespace
```

## Environment Tasks

These tasks help manage the development and testing environments.

| Task | Description | Related Workflow Stage |
|------|-------------|------------------------|
| `cluster-create` | Creates a test Kubernetes cluster using Replicated's Compatibility Matrix | Stage 4: Single Chart Install |
| `setup-kubeconfig` | Retrieves and sets up the kubeconfig for the test cluster | Stage 4: Single Chart Install |
| `delete-cluster` | Deletes the test cluster and cleans up resources | Stage 4-5: Cleanup |
| `list-cluster` | List the test cluster with the cluster id, name, and expiration date | Stage 4: Single Chart Install |
| `verify-kubeconfig` | Verifies the kubeconfig for the test cluster and removes the cluster if it is expired | Stage 4: Single Chart Install |
| `cluster-delete` | Deletes the test cluster and cleans up resources | Stage 4-5: Cleanup |
| `gcp-vm-create` | Creates a GCP VM instance for embedded cluster testing | Stage 7: Embedded Testing |
| `gcp-vm-delete` | Deletes the GCP VM instance after testing | Stage 7: Cleanup |
| `embedded-cluster-setup` | Sets up a Replicated embedded cluster on the GCP VM | Stage 7: Embedded Testing |
| `cmx-vm-create` | Creates a CMX VM instance using Replicated CLI | Stage 7: Embedded Testing |
| `cmx-vm-delete` | Deletes a CMX VM instance | Stage 7: Cleanup |
| `cmx-vm-install` | Downloads and optionally installs the app as Embedded Cluster on CMX VM | Stage 7: Embedded Testing |

### Common Environment Combinations

**Create Test Environment:**
```bash
task cluster-create && task setup-kubeconfig
OR
task setup-kubeconfig
```

While tasks can be run in order, they also have dependencies. Running the get-kubeconfig task for example will also create a cluster if the test cluster hasn't been created already.

**Cleanup After Testing:**
```bash
task cluster-delete
```

Creating a cluster can take up to 5 minutes and helm charts should be uninstalled/reinstalled while developing rather than removing the entire cluster to iterate in seconds rather than minutes.

## Release Tasks

These tasks support preparing and creating releases.

| Task | Description | Related Workflow Stage |
|------|-------------|------------------------|
| `release-prepare` | Packages charts and merges configuration files for release | Stage 6: Release Preparation |
| `release-create` | Creates and promotes a release using the Replicated CLI | Stage 6: Release Preparation |
| `test` | Runs basic validation tests against the deployed application | Stage 5-7: Validation |

TODO: The test task is a placeholder currently it just sleeps and returns positive.

### Release Process Example

```bash
task release-prepare && task release-create CHANNEL=Beta
```

## Automation Tasks

These tasks provide end-to-end automation combining multiple individual tasks.

| Task | Description | Related Workflow Stages |
|------|-------------|-------------------------|
| `full-test-cycle` | Runs a complete test cycle from cluster creation to deletion | Stages 4-5: Full Testing |

This task performs the following sequence:

1. Creates a cluster
2. Sets up the kubeconfig
3. Exposes ports
4. Updates dependencies
5. Runs preflight checks on charts
6. Installs all charts
7. Runs tests
8. Deletes the cluster

## Task Parameters

Many tasks accept parameters to customize their behavior. Here are the most commonly used parameters:

| Parameter | Used With | Description | Default |
|-----------|-----------|-------------|---------|
| `CLUSTER_NAME` | `cluster-create`, `setup-kubeconfig` | Name for the cluster | "test-cluster" |
| `K8S_VERSION` | `cluster-create` | Kubernetes version | "1.32.2" |
| `DISTRIBUTION` | `cluster-create` | Cluster distribution | "k3s" |
| `DRY_RUN` | `helm-preflight` | Run preflight checks in dry-run mode | "false" |
| `CHANNEL` | `release-create` | Channel to promote to | "Unstable" |
| `RELEASE_NOTES` | `release-create` | Notes for the release | "" |
| `GCP_PROJECT` | `gcp-vm-create` | GCP project ID | Required |
| `GCP_ZONE` | `gcp-vm-create` | GCP zone | "us-central1-a" |
| `CMX_VM_NAME` | `cmx-vm-create`, `cmx-vm-delete`, `cmx-vm-install` | Name for the CMX VM | "{{USER}}-cmx-vm" |
| `CMX_VM_DISTRIBUTION` | `cmx-vm-create` | VM distribution | "ubuntu" |
| `CMX_VM_VERSION` | `cmx-vm-create` | VM version | "24.04" |
| `CMX_VM_INSTANCE_TYPE` | `cmx-vm-create` | VM instance type | "r1.medium" |
| `CMX_VM_DISK_SIZE` | `cmx-vm-create` | VM disk size in GB | "100" |
| `CMX_VM_TTL` | `cmx-vm-create` | VM time-to-live | "1h" |
| `CMX_VM_USER` | `cmx-vm-install` | VM user for SSH access | Required |
| `CMX_VM_PUBLIC_KEY` | `cmx-vm-install` | Path to SSH public key | "" |
| `SKIP_INSTALL` | `cmx-vm-install` | Skip the installation step, only download binary | "false" |

Parameters in the Taskfile.yaml try to always have defaults so that it works out of the box but allows customization for common values.

## Supporting the Development Workflow

These tasks are designed to support the progressive complexity approach:

1. **Early Stages** - Use `dependencies-update` and helm commands directly
2. **Middle Stages** - Use `cluster-create`, `helm-install`,  and `test`
3. **Later Stages** - Use `release-prepare`, `release-create`, and embedded cluster tasks

This organization allows developers to focus on the appropriate level of complexity at each stage of development.

## Cross-References to Workflow Stages

Refer to the [Development Workflow](development-workflow.md) document for details on each stage and when to use specific tasks.
