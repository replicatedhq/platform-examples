# MLflow Development Guide

This document provides information about developing, testing, and releasing the MLflow application using the included Taskfile.

## Development

## Prerequisites

- Docker
- [Task](https://taskfile.dev/installation/) - A task runner / simpler Make alternative

Optional (for direct installation on your machine):
- go (1.20+)
- Helm
- kubectl

## Development Workflow

We use a [Taskfile](https://taskfile.dev/) to manage development tasks. The recommended approach is to use our containerized development environment, which includes all necessary dependencies.

### Containerized Development Environment

Our Docker-based development environment provides:
* Consistent environment across team members
* All required dependencies pre-installed
* No need to install Go, Python, Helm, or other tools locally
* Works on any operating system with Docker support

To get started:

```bash
# Build the development image
task dev:build-image

# Start a development container
# This creates and runs the container in the background
task dev:start

# Enter a shell in an already running development container
task dev:shell
```

The tasks above will:
1. Build the development Docker image if needed
2. Start a container with the proper mounts and environment
3. Provide you with a shell inside the container
4. Allow you to run all task commands directly

### Common Development Tasks

Once you're inside the development container (or on your local machine with all prerequisites installed), you can run these common tasks:

```bash
# Update Helm dependencies
task helm:update-deps

# Lint the Helm chart
task helm:lint

# Template the chart (no values overrides)
task helm:template

# Install the chart to your Kubernetes cluster
task helm:install-local

# Run application tests
task test:app
```

### Development Workflow Steps

1. Set up the development environment:
   ```bash
   task dev:build-image
   ```

2. Start the development container:
   ```bash
   task dev:start
   ```

3. Enter the development container:
   ```bash
   task dev:shell
   ```

4. Update Helm dependencies:
   ```bash
   task helm:update-deps
   ```

5. Lint and template charts to check for issues:
   ```bash
   task helm:lint
   task helm:template
   ```

6. Install charts for development:
   ```bash
   # Installs with Replicated SDK disabled
   task helm:install-local
   
   # Optionally specify a custom values file
   MLFLOW_VALUES=./my-values.yaml task helm:install-local
   ```

   > **Note:** For local development, the Replicated SDK is explicitly disabled (`replicated.enabled=false`). This allows development without requiring access to the Replicated platform.
   >
   > This task automatically sets up port forwarding from localhost:5000 to the MLflow service in the cluster, making the application available for testing.
   > 
   > The Helm releases are created with names `infra` and `mlflow` in the `mlflow` namespace.

7. Run application tests:
   ```bash
   task test:app
   ```

8. Make changes to your charts and repeat steps 5-7 as needed

This workflow allows rapid iteration without needing to publish to the Replicated registry.

### Container Management

If you encounter issues with the container:

- Stop the container: `task dev:stop`
- Restart it: `task dev:restart`
- Rebuild the image if needed: `task dev:build-image`

## Creating a Release

When you're ready to publish your changes to the Replicated platform:

1. Update the version in `charts/mlflow/Chart.yaml` if necessary.

2. Update documentation:
   ```bash
   # Generate Helm documentation
   task helm:docs:generate
   ```

3. Set up the required environment variables:
   ```bash
   # Replicated API token for authentication
   export REPLICATED_API_TOKEN=your_api_token
   
   # App and channel to publish to
   export REPLICATED_APP=app_slug
   export REPLICATED_CHANNEL=channel_name
   ```

4. Package the charts and update version references:
   ```bash
   # This updates KOTS manifests with the current chart versions
   # and packages the charts as .tgz files
   task helm:package
   ```

5. Create a release in Replicated:
   ```bash
   # This uploads the packaged charts and creates a new release
   task release:create
   ```

6. Verify the release was created successfully in the Replicated vendor portal

### Testing Replicated Releases

This workflow tests the full Replicated release and distribution process:

1. After publishing a release, login to the registry with a license ID:
   ```bash
   # Set license ID for registry authentication
   export REPLICATED_LICENSE_ID=your_license_id
   export REPLICATED_APP=app_slug
   export REPLICATED_CHANNEL=channel_name
   
   # Login to the registry
   task registry:login
   ```

2. Test the Helm installation from the Replicated registry:
   ```bash
   # This pulls charts from the Replicated registry with SDK enabled
   task helm:test-install
   ```

   > **Note:** This creates Helm releases named `infra` and `mlflow` in the `mlflow` namespace.

3. Verify the installation with application tests:
   ```bash
   task test:app
   ```

You can also run the complete test suite after setting up environment variables:
```bash
task test:all
```

This workflow validates the entire release pipeline from publishing to installation, ensuring that your charts work correctly when distributed through the Replicated platform.

## Troubleshooting

### Container Issues

If you encounter issues with the container:

- Stop the container: `task dev:stop`
- Restart it: `task dev:restart`
- Rebuild the image if needed: `task dev:build-image`

### Port Forwarding Issues

If you encounter issues with port forwarding:

1. Check if the port is already in use on your host machine
2. Try using a different port by specifying it when starting the service
3. The development environment automatically tries ports 5000-5004 and will use the first available one

## CI/CD Pipeline Integration

For CI, we push the development image to ttl.sh with:

```bash
task ci:push-image
```

The MLflow application includes a CI/CD pipeline implemented with GitHub Actions. The pipeline handles:

- Linting and validating Helm chart templates
- Creating releases in Replicated
- Testing Helm installation with charts from the Replicated registry
- Installing the application via KOTS

The pipeline workflow:
1. `lint-and-template`: Validates chart syntax and templates (SDK disabled)
2. `create-release`: Packages charts and creates a release in Replicated
3. `helm-install-test`: Tests Helm installation with charts from Replicated registry (SDK enabled)
4. `kots-install-test`: Tests KOTS installation
5. `cleanup-test-release`: Cleans up test resources

For more details, see the workflow definition in [.github/workflows/mlflow-ci.yml](../../.github/workflows/mlflow-ci.yml).
