# MLflow Development Guide

This document provides information about developing, testing, and releasing the MLflow application using the included Taskfile.

## Development Workflow

The MLflow application includes a Taskfile.yml that provides tasks for developing, testing, and publishing the application.

### Prerequisites

- [Task](https://taskfile.dev/#/installation) command line tool
- Kubernetes cluster configured in your current context
- kubectl, helm, and python3 installed

### Local Development

Follow this workflow for development:

1. Add required Helm repositories and update dependencies:
   ```bash
   task update:deps:helm
   ```

2. Lint charts to check for issues:
   ```bash
   task lint
   ```

3. Template charts to verify the rendered manifests:
   ```bash
   task template
   ```

4. Install charts for development:
   ```bash
   # Installs with Replicated SDK disabled
   task install:helm:local
   
   # Optionally specify a custom values file
   MLFLOW_VALUES=./my-values.yaml task install:helm:local
   ```

   > **Note:** For local development, the Replicated SDK is explicitly disabled (`replicated.enabled=false`). This allows development without requiring access to the Replicated platform.
   >
   > This task automatically sets up port forwarding from localhost:5000 to the MLflow service in the cluster, making the application available for testing.
   > 
   > The Helm releases are created with names `infra` and `mlflow` in the `mlflow` namespace.

5. Run application tests:
   ```bash
   task run:tests:app
   ```

6. Make changes to your charts and repeat steps 2-5 as needed

This workflow allows rapid iteration without needing to publish to the Replicated registry.

## Releasing

### Updating Documentation

Before creating a release, ensure the documentation is up-to-date:

1. Update version information in `charts/mlflow/Chart.yaml` if needed.

2. Update the changelog in `charts/mlflow/README_CHANGELOG.md.gotmpl` with details about the new release.

3. Generate documentation using helm-docs:
   ```bash
   # From the mlflow chart directory
   cd charts/mlflow
   
   # If helm-docs is installed locally
   helm-docs
   
   # Or use Docker
   docker run --rm -v "$(pwd):/helm-docs" -u $(id -u) jnorwood/helm-docs:latest
   ```

4. Verify the generated documentation:
   - `README.md` - Main chart documentation
   - `README_CHANGELOG.md` - Changelog
   - `README_CONFIG.md` - Configuration reference

### Publishing Replicated Releases

When you're ready to publish your changes to the Replicated platform:

1. Update the version in `charts/mlflow/Chart.yaml` if necessary.

2. Update documentation:
   ```bash
   # If helm-docs is not installed
   cd charts/mlflow
   docker run --rm -v "$(pwd):/helm-docs" -u $(id -u) jnorwood/helm-docs:latest
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
   task package:charts
   ```

5. Create a release in Replicated:
   ```bash
   # This uploads the packaged charts and creates a new release
   task create:release
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
   task login:registry
   ```

2. Test the Helm installation from the Replicated registry:
   ```bash
   # This pulls charts from the Replicated registry with SDK enabled
   task test:install:helm
   ```

   > **Note:** This creates Helm releases named `infra` and `mlflow` in the `mlflow` namespace.

3. Verify the installation with application tests:
   ```bash
   task run:tests:app
   ```

You can also run the complete test suite after setting up environment variables:
```bash
task run:tests:all
```

This workflow validates the entire release pipeline from publishing to installation, ensuring that your charts work correctly when distributed through the Replicated platform.

## CI/CD Pipeline

This application includes a CI/CD pipeline implemented with GitHub Actions. The pipeline handles:

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

The pipeline is triggered on:
- Pull requests affecting the MLflow application
- Pushes to the main branch

For more details, see the workflow definition in [.github/workflows/mlflow-ci.yml](../../.github/workflows/mlflow-ci.yml).
