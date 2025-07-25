# Development Workflow

This document outlines the progressive development workflow for the WG-Easy Helm chart pattern, guiding you through each stage from initial chart configuration to complete application deployment.

## Progressive Complexity Approach

The core philosophy of this workflow is to start simple and add complexity incrementally, providing fast feedback at each stage. This allows developers to:

- Identify and fix issues early when they're easier to debug
- Get rapid feedback on changes without waiting for full deployments
- Build confidence in changes through progressive validation
- Maintain high velocity while ensuring quality

## Prerequisites

Before starting the development workflow, ensure you have the following tools installed:

- **Task:** The task runner used in this project. ([Installation Guide](https://taskfile.dev/installation/))
- **Container runtime tool** Either [Podman](https://podman.io/docs/installation) (default) or [Docker](https://docs.docker.com/get-docker/) for local development. Export `CONTAINER_RUNTIME=docker` in your shell if you use docker.
- **Replicated API Token:** Export `REPLICATED_API_TOKEN` in your shell. This can be obtained from the [Replicated Vendor Portal](https://vendor.replicated.com) under Account Settings → API Tokens.

  ```bash
  # Add to your shell's rc file (.bashrc, .zshrc, etc.)
  export REPLICATED_API_TOKEN="<your-token-here>"
  ```

All other tools will be automatically provided through task commands and containers.

### Debugging with Verbose Mode

All tasks run in silent mode by default. When debugging issues or understanding what's happening during development, use the verbose flag:

```bash
# Show detailed execution for debugging
task -v cluster-create
task -v helm-install

# Standard silent output for production use
task cluster-create
task helm-install
```

## Workflow Stages

### Stage 1: Chart Dependencies and Verification

Begin by defining and verifying chart dependencies.

1. Define or update dependencies in `Chart.yaml`:

   ```yaml
   # Example: charts/cert-manager/Chart.yaml
   dependencies:
     - name: cert-manager
       version: '1.14.5'
       repository: https://charts.jetstack.io
     - name: templates
       version: '*'
       repository: file://../templates
   ```

2. Update dependencies:

   ```bash
   task dependencies-update
   # Or for a single chart:
   helm dependency update ./charts/cert-manager
   ```

3. Verify charts were downloaded:

   ```bash
   ls -la ./charts/cert-manager/charts/
   ```

**Validation point**: Dependencies should be successfully downloaded to the `/charts` directory.

### Stage 2: Configuration with values.yaml and Templates

Configure chart values and create or modify templates.

1. Update the chart's `values.yaml` with appropriate defaults:

   ```yaml
   # Example: traefik/values.yaml
   certs:
     selfSigned: true
   traefik:
     service:
       type: NodePort
     ports:
       web:
         nodePort: 80
   ```

2. Create or customize templates:

   ```yaml
   # Example: Adding a template for TLS configuration
   apiVersion: traefik.containo.us/v1alpha1
   kind: TLSOption
   metadata:
    name: default
    namespace: traefik
   spec:
     minVersion: VersionTLS12
   ```

**Validation point**: Configuration values are properly defined and templates are syntactically correct.

### Stage 3: Local Validation with helm template

> [!IMPORTANT]
> Tools required by tasks in this project will be made available in a container. Run the commands below to start the dev environment

```
# Open shell to execute tasks
task dev:shell

# Start/restart tools container. Idempotent.
task dev:restart
```

Validate chart templates locally without deploying to a cluster.

1. Run helm template to render the chart and inspect manifests:
   ```bash
   helm template ./charts/cert-manager | less
   ```

**Validation point**: Generated Kubernetes manifests should be valid and contain the expected resources.

### Stage 4: Single Chart Install/Uninstall

Deploy individual charts to a test cluster to verify functionality.

1. Create a test cluster if needed:

   ```bash
   # Create with default name (test-cluster)
   task cluster-create

   # Create with custom name
   task cluster-create CLUSTER_NAME=my-custom-cluster

   # Create embedded cluster with custom name
   task cluster-create CLUSTER_NAME=my-embedded-cluster EMBEDDED=true

   task setup-kubeconfig
   ```

   **Debugging cluster issues:**
   ```bash
   # Use verbose mode to see detailed cluster creation process
   task -v cluster-create
   task -v setup-kubeconfig
   
   # Check cluster status manually
   task cluster-list
   ```

2. Run preflight checks on your chart:

   ```bash
   task helm-preflight
   # Or for a single chart with dry-run:
   helm template ./charts/wg-easy | kubectl preflight - --dry-run
   ```

   **Debugging preflight issues:**
   ```bash
   # See detailed preflight execution
   task -v helm-preflight
   ```

3. Install a single chart:

   ```bash
   helm install cert-manager ./charts/cert-manager -n cert-manager --create-namespace
   ```

4. Verify the deployment:

   ```bash
   kubectl get pods -n cert-manager
   ```

5. Test chart functionality:

   ```bash
   # Example: Test cert-manager with a test certificate
   kubectl apply -f ./some-test-certificate.yaml
   kubectl get certificate -A
   ```

6. Uninstall when done or making changes and repeat step 3:

   ```bash
   helm uninstall cert-manager -n cert-manager
   ```

**Validation point**: Preflight checks should pass without errors, and the chart should deploy successfully and function as expected.

### Stage 5: Integration Testing with helmfile

Test multiple charts working together using Helmfile orchestration.

1. Ensure helmfile.yaml.gotmpl is configured with the correct dependencies:

   ```yaml
   releases:
     - name: cert-manager
       namespace: cert-manager
       chart: ./cert-manager
       # ...
     - name: cert-manager-issuers
       namespace: cert-manager
       chart: ./charts/cert-manager-issuers
       # ...
       needs:
         - cert-manager/cert-manager
   ```

2. Deploy all charts:

   ```bash
   # set a license id so we can perform the helm install from the replicated registry
   export REPLICATED_LICENSE_ID=<customer license id>
   task helm-install

   # or to deploy using the replicated released OCI charts
   task helm-install HELM_ENV=replicated
   ```

3. Verify cross-component integration:

   ```bash
   # Check if issuers are correctly using cert-manager
   kubectl get clusterissuers
   kubectl get issuers -A

   # Verify Traefik routes
   kubectl get ingressroutes -A
   ```

**Validation point**: All components should deploy in the correct order and work together.

### Stage 6: Release Preparation

Prepare a release package for distribution.

1. Generate release files:

   ```bash
   task release-prepare
   ```

2. Inspect the generated release files:

   ```bash
   ls -la ./release/
   ```

3. Create a release:

   ```bash
   task release-create
   ```

**Validation point**: Release files should be correctly generated and the release should be created successfully.

### Stage 7: Test installing a helm based release

TODO: Finish implementing helm based release testing

### Stage 8: Embedded Cluster Testing

Test the full application and configuration screen in a using an embedded cluster.

1. Create a VM for testing:

   ```bash
   task gcp-vm-create
   ```

2. Set up an embedded cluster:

   ```bash
   task embedded-cluster-setup
   ```

3. Verify the application:

   ```bash
   # Test accessing the application frontend
   echo "Application URL: https://<VM-IP>"
   ```

**Validation point**: Verify configuration workflow, preflight, and other Embedded Cluster configurations.

## Moving Between Stages

The workflow is designed to be iterative. Here are guidelines for when to move from one stage to the next:

- **Move forward** when the current stage validation passes without issues
- **Move backward** when problems are detected to diagnose and fix at a simpler level
- **Stay in a stage** if you're making changes focused on that particular level of complexity

## Fast Feedback Examples

Each stage provides fast feedback:

1. **Chart Dependencies**: Immediate feedback on dependency resolution (seconds)
2. **Values Configuration**: Immediate feedback on configuration structure (seconds)
3. **Template Validation**: Fast feedback on template rendering (seconds)
4. **Single Chart Install**: Quick feedback on chart functionality (1-2 minutes)
5. **Integration Testing**: Feedback on component interaction (5-10 minutes)
6. **Release Preparation**: Feedback on release packaging (seconds)
7. **Embedded Testing**: Full system feedback (10-15 minutes)

This progressive approach allows you to catch and fix issues at the earliest possible stage, minimizing the time spent debugging complex problems in fully deployed environments.
