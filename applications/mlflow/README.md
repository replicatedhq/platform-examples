# MLflow

MLflow is an open-source platform for managing the machine learning lifecycle, including experimentation, reproducibility, deployment, and a central model registry. This application provides a Helm-based deployment of MLflow with support for Replicated distribution.

## Development

The MLflow application includes a Taskfile.yml that provides tasks for developing, testing, and publishing the application.

### Prerequisites

- [Task](https://taskfile.dev/#/installation) command line tool
- Kubernetes cluster configured in your current context
- kubectl, helm, and python3 installed

### Development Workflow

Follow this workflow for development:

1. Add required Helm repositories and update dependencies:
   ```bash
   task add:repos:helm
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

5. Run application tests:
   ```bash
   task run:tests:app
   ```

6. Make changes to your charts and repeat steps 2-5 as needed

This workflow allows rapid iteration without needing to publish to the Replicated registry.

### Task Reference

Tasks follow a `verb:resource[:subresource]` naming convention for clarity:

```bash
# Validation and verification
task lint                 # Lint Helm charts
task template             # Render templates to stdout (SDK disabled)
task check:versions       # Verify Chart.yaml and KOTS manifest versions match

# Repository and dependency management
task add:repos:helm       # Add required Helm repositories
task update:deps:helm     # Update Helm chart dependencies

# Packaging and versioning
task update:versions:chart # Update chart version refs in KOTS manifests
task package:charts       # Package Helm charts for distribution
task extract:version:chart # Extract current MLflow chart version

# Installation
task install:helm:local   # Install charts for local development (SDK disabled)

# Testing
task test:install:helm    # Test with charts from Replicated registry
task test:install:kots    # Test KOTS installation
task run:tests:app        # Run application tests against running MLflow
task run:tests:all        # Run all tests (Helm install + app tests)

# Release management
task create:release       # Create a Replicated release

# Cleanup
task clean:files:charts   # Clean packaged chart files
task clean:all            # Clean all generated files
```

### Publishing Replicated Releases

When you're ready to publish your changes to the Replicated platform:

1. Set up the required environment variables:
   ```bash
   # Replicated API token for authentication
   export REPLICATED_API_TOKEN=your_api_token
   
   # App and channel to publish to
   export REPLICATED_APP=app_slug
   export REPLICATED_CHANNEL=channel_name
   ```

2. Package the charts and update version references:
   ```bash
   # This updates KOTS manifests with the current chart versions
   # and packages the charts as .tgz files
   task package:charts
   ```

3. Create a release in Replicated:
   ```bash
   # This uploads the packaged charts and creates a new release
   task create:release
   ```

4. Verify the release was created successfully in the Replicated vendor portal

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

3. Verify the installation with application tests:
   ```bash
   task run:tests:app
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
