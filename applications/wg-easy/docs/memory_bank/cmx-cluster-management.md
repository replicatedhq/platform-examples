# CMX Cluster Management Workflow

This document explains the CMX cluster management tasks added to the Taskfile and how they support the development workflow.

## Overview

The CMX (Compatibility Matrix) cluster management tasks provide a streamlined way to create, manage, and delete test Kubernetes clusters for development and testing of Helm charts. These tasks leverage the Replicated CLI's cluster management capabilities to provide a consistent and reproducible environment.

## CMX Cluster Management Tasks

The following tasks have been added to the `Taskfile.yml`:

### 1. `create-cmx-cluster`

Creates a new Kubernetes cluster using Replicated's Compatibility Matrix service.

**Parameters:**
- `CLUSTER_NAME`: Name for the cluster (default: test-cluster)
- `DISTRIBUTION`: Kubernetes distribution (default: k3s)
- `K8S_VERSION`: Kubernetes version (default: 1.32.2)
- `DISK_SIZE`: Disk size in GB (default: 100)
- `INSTANCE_TYPE`: VM instance type (default: r1.small)
- `TIMEOUT`: Maximum wait time in seconds (default: 300)

**Example:**
```bash
task create-cmx-cluster CLUSTER_NAME=dev-cluster K8S_VERSION=1.28.0
```

### 2. `setup-cmx-kubeconfig`

Retrieves and saves the kubeconfig for a CMX cluster. If the specified cluster doesn't exist, it will be created automatically.

**Parameters:**
- `CLUSTER_NAME`: Name of the cluster (default: test-cluster)
- `KUBECONFIG_FILE`: Path to save the kubeconfig (default: kubeconfig.yaml)

**Example:**
```bash
task setup-cmx-kubeconfig KUBECONFIG_FILE=~/.kube/cmx-config
```

### 3. `list-cmx-cluster`

Lists all CMX clusters with detailed information about the specified cluster.

**Parameters:**
- `CLUSTER_NAME`: Name of the cluster to focus on (default: test-cluster)

**Example:**
```bash
task list-cmx-cluster CLUSTER_NAME=dev-cluster
```

### 4. `verify-cmx-kubeconfig`

Verifies that the kubeconfig for the CMX cluster is working correctly by running basic kubectl commands.

**Parameters:**
- `KUBECONFIG_FILE`: Path to the kubeconfig file (default: kubeconfig.yaml)

**Example:**
```bash
task verify-cmx-kubeconfig KUBECONFIG_FILE=~/.kube/cmx-config
```

### 5. `delete-cmx-cluster`

Deletes the specified CMX cluster.

**Parameters:**
- `CLUSTER_NAME`: Name of the cluster to delete (default: test-cluster)

**Example:**
```bash
task delete-cmx-cluster CLUSTER_NAME=dev-cluster
```

## Helper Tasks

In addition to the main CMX cluster management tasks, the following helper task has been added:

### `wait-for-cluster`

An internal task that waits for a cluster to reach the "running" state.

**Parameters:**
- `CLUSTER_NAME`: Name of the cluster (default: test-cluster)
- `TIMEOUT`: Maximum wait time in seconds (default: 300)

This task is used internally by other tasks and is not typically called directly.

## Typical Workflow

A typical workflow using these tasks would look like:

1. **Create a new cluster and set up kubeconfig:**
   ```bash
   task setup-cmx-kubeconfig CLUSTER_NAME=my-dev-cluster
   ```

2. **Verify the kubeconfig is working:**
   ```bash
   task verify-cmx-kubeconfig
   ```

3. **Install and test Helm charts:**
   ```bash
   export KUBECONFIG=kubeconfig.yaml
   task helm-install
   task helm-test
   ```

4. **Delete the cluster when done:**
   ```bash
   task delete-cmx-cluster
   ```

## Integration with Helm Tasks

The CMX cluster management tasks are designed to work seamlessly with the existing Helm tasks:

1. Create a cluster with `create-cmx-cluster` or `setup-cmx-kubeconfig`
2. Export the KUBECONFIG environment variable to point to the generated kubeconfig file
3. Use the Helm tasks (`helm-install`, `helm-test`, etc.) to deploy and test your charts
4. Clean up with `delete-cmx-cluster` when finished

This integration enables a complete development workflow from cluster creation to Helm chart deployment and testing.

## Best Practices

- **Use descriptive cluster names** for different development purposes (e.g., `dev-testing`, `integration`, etc.)
- **Clean up clusters when done** to avoid unnecessary resource usage
- **Set the KUBECONFIG environment variable** after creating a cluster for easier interaction with kubectl and Helm
- **Use the appropriate Kubernetes version and distribution** for your testing needs
- **Create automated pipelines** combining cluster creation, chart deployment, testing, and cluster cleanup

## Limitations

- Cluster creation can take up to 5 minutes
- If fast iteration is needed, prefer to update existing charts rather than recreating clusters
- Clusters automatically expire after 24 hours if not deleted manually 
