# Task Reference

This document provides a concise reference for the tasks available in the WG-Easy Helm chart development pattern, organized by their purpose in the development workflow.

## Development Tasks

These tasks support the iterative development process, focusing on fast feedback loops.

| Task | Description | Related Workflow Stage |
|------|-------------|------------------------|
| `update-dependencies` | Updates Helm dependencies for all charts in the repository | Stage 1: Dependencies |
| `deploy-helm` | Deploys all charts using helmfile with proper sequencing | Stage 5: Integration Testing |
| `expose-ports` | Exposes the configured ports on the cluster for testing | Stage 4-5: Chart Installation/Integration |
| `remove-k3s-traefik` | Removes pre-installed Traefik from k3s clusters to avoid conflicts | Stage 4-5: Chart Installation/Integration |

### Common Development Combinations

**Complete Update and Deploy:**
```bash
task update-dependencies && task deploy-helm
```

**Single Chart Testing:**
```bash
helm dependency update ./traefik
helm install traefik ./traefik -n traefik --create-namespace
```

## Environment Tasks

These tasks help manage the development and testing environments.

| Task | Description | Related Workflow Stage |
|------|-------------|------------------------|
| `create-cluster` | Creates a test Kubernetes cluster using Replicated's Compatibility Matrix | Stage 4: Single Chart Install |
| `setup-kubeconfig` | Retrieves and sets up the kubeconfig for the test cluster | Stage 4: Single Chart Install |
| `delete-cluster` | Deletes the test cluster and cleans up resources | Stage 4-5: Cleanup |
| `create-gcp-vm` | Creates a GCP VM instance for embedded cluster testing | Stage 7: Embedded Testing |
| `delete-gcp-vm` | Deletes the GCP VM instance after testing | Stage 7: Cleanup |
| `setup-embedded-cluster` | Sets up a Replicated embedded cluster on the GCP VM | Stage 7: Embedded Testing |

### Common Environment Combinations

**Create Test Environment:**
```bash
task create-cluster && task setup-kubeconfig
OR
task setup-kubeconfig
```

While tasks can be run in order, they also have dependencies. Running the get-kubeconfig task for example will also create a cluster if the test cluster hasn't been created already.

**Cleanup After Testing:**
```bash
task delete-cluster
```

Creating a cluster can take up to 5 minutes and helm charts should be uninstalled/reinstalled while developing rather than removing the entire cluster to iterate in seconds rather than minutes.

## Release Tasks

These tasks support preparing and creating releases.

| Task | Description | Related Workflow Stage |
|------|-------------|------------------------|
| `prepare-release` | Packages charts and merges configuration files for release | Stage 6: Release Preparation |
| `release-create` | Creates and promotes a release using the Replicated CLI | Stage 6: Release Preparation |
| `test` | Runs basic validation tests against the deployed application | Stage 5-7: Validation |

TODO: The test task is a placeholder currently it just sleeps and returns positive.

### Release Process Example

```bash
task prepare-release && task release-create CHANNEL=Beta
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
4. Removes pre-installed Traefik
5. Updates dependencies
6. Deploys all charts
7. Runs tests
8. Deletes the cluster

## Task Parameters

Many tasks accept parameters to customize their behavior. Here are the most commonly used parameters:

| Parameter | Used With | Description | Default |
|-----------|-----------|-------------|---------|
| `CLUSTER_NAME` | `create-cluster`, `setup-kubeconfig` | Name for the cluster | "test-cluster" |
| `K8S_VERSION` | `create-cluster` | Kubernetes version | "1.32.2" |
| `DISTRIBUTION` | `create-cluster` | Cluster distribution | "k3s" |
| `CHANNEL` | `release-create` | Channel to promote to | "Unstable" |
| `RELEASE_NOTES` | `release-create` | Notes for the release | "" |
| `GCP_PROJECT` | `create-gcp-vm` | GCP project ID | Required |
| `GCP_ZONE` | `create-gcp-vm` | GCP zone | "us-central1-a" |

Parameters in the Taskfile.yaml try to always have defaults so that it works out of the box but allows customization for common values.

## Supporting the Development Workflow

These tasks are designed to support the progressive complexity approach:

1. **Early Stages** - Use `update-dependencies` and helm commands directly
2. **Middle Stages** - Use `create-cluster`, `deploy-helm`,  and `test`
3. **Later Stages** - Use `prepare-release`, `release-create`, and embedded cluster tasks

This organization allows developers to focus on the appropriate level of complexity at each stage of development.

## Cross-References to Workflow Stages

Refer to the [Development Workflow](development-workflow.md) document for details on each stage and when to use specific tasks.

## Example Replicated CLI Commands

1. create a replicated cmx cluster
```
CLUSTER_NAME=test-cluster
DISTRIBUTION=k3s
K8S_VERSION=1.32.2
DISK_SIZE=100
INSTANCE_TYPE=r1.small

replicated cluster create --name {{.CLUSTER_NAME}} --distribution {{.DISTRIBUTION}} --version {{.K8S_VERSION}} --disk {{.DISK_SIZE}} --instance-type {{.INSTANCE_TYPE}}
```

2. get the kubeconfig for the cluster
```
replicated cluster kubeconfig --name {{.CLUSTER_NAME}} --output-path {{.KUBECONFIG_FILE}}
```

3. filter the cmx cluster
```
replicated cluster ls --output json | jq -e '.[] | select(.name == "{{.CLUSTER_NAME}}")'
CLUSTER_ID=$(replicated cluster ls --output json | jq -r '.[] | select(.name == "{{.CLUSTER_NAME}}") | .id')
```

4. delete the cmx cluster
```
replicated cluster rm {{.CLUSTER_ID}}
```

