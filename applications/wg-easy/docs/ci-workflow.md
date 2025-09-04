# WG-Easy CI Workflow Documentation

## Overview

The wg-easy application uses a comprehensive CI/CD pipeline that validates pull requests by testing the application across multiple Kubernetes distributions and versions. This ensures compatibility and reliability before merging changes to the main branch.

## Workflow Triggers

The CI workflow is triggered on:
- **Pull requests** to the `main` branch that affect files in `applications/wg-easy/`
- **Manual workflow dispatch** with optional test mode parameter

## Workflow Architecture

### Job Sequence

The workflow consists of several sequential jobs that build upon each other:

1. **Setup** - Configures branch and channel naming conventions
2. **Validate Charts** - Validates Helm charts and Taskfile syntax
3. **Build and Package** - Packages charts and creates release artifacts
4. **Create Resources** - Creates Replicated resources (channels, customers, licenses)
5. **Create Clusters** - Creates test clusters across multiple K8s versions
6. **Test Deployment** - Deploys and tests the application

### Concurrency Control

- Uses concurrency groups to prevent multiple workflows from conflicting
- Cancels in-progress workflows when new commits are pushed
- Limits parallel cluster creation to manage resource usage

## Replicated CLI Integration

### Cluster Management

The workflow uses Replicated CLI extensively for cluster lifecycle management:

```bash
# Create test clusters
replicated cluster create \
  --name "$CLUSTER_NAME" \
  --distribution "$DISTRIBUTION" \
  --version "$K8S_VERSION" \
  --disk "50" \
  --instance-type "$INSTANCE_TYPE" \
  --nodes "$NODE_COUNT" \
  --ttl "$TTL"

# List and manage clusters
replicated cluster ls --output json
replicated cluster kubeconfig --name "$CLUSTER_NAME" --output-path /tmp/kubeconfig
replicated cluster rm "$CLUSTER_ID"
```

### Release Management

Releases are created using the `replicatedhq/replicated-actions/create-release` GitHub Action:

```yaml
- name: Create Replicated release
  uses: replicatedhq/replicated-actions/create-release@v1.19.0
  with:
    app-slug: ${{ env.REPLICATED_APP }}
    api-token: ${{ env.REPLICATED_API_TOKEN }}
    yaml-dir: ${{ env.APP_DIR }}/release
    promote-channel: ${{ needs.setup.outputs.channel-name }}
```

### Customer and License Management

```bash
# Create customers
replicated customer create \
  --app-slug $APP_SLUG \
  --customer-name $CUSTOMER_NAME \
  --channel-slug $CHANNEL_SLUG \
  --license-type dev

# Retrieve customer information
replicated customer ls --output json | jq -r '.[] | select(.name == "$CUSTOMER_NAME") | .installationId'
```

### Channel Management

```bash
# List and manage channels
replicated channel ls --app $APP_SLUG --output json
replicated channel ls --app $APP_SLUG --output json | jq -r '.[] | select(.name == "$CHANNEL_NAME") | .id'
```

## Application Deployment Process

### 1. Resource Preparation

The deployment process begins by ensuring all necessary resources exist:

- **Customer**: Created or retrieved by name
- **License**: Generated for the customer with dev license type
- **Channel**: Created from branch name (normalized to lowercase with hyphens)
- **Cluster**: Created with specific Kubernetes version and distribution

### 2. Kubeconfig Setup

```bash
# Get cluster kubeconfig
replicated cluster kubeconfig --name "$CLUSTER_NAME" --output-path /tmp/kubeconfig

# Validate cluster connectivity
kubectl cluster-info
kubectl wait --for=condition=Ready nodes --all --timeout=300s
```

### 3. Application Installation

The app is deployed using the `customer-helm-install` task:

```bash
task customer-helm-install \
  CUSTOMER_NAME="$CUSTOMER_NAME" \
  CLUSTER_NAME="$CLUSTER_NAME" \
  CHANNEL_SLUG="$CHANNEL_SLUG" \
  REPLICATED_LICENSE_ID="$LICENSE_ID"
```

#### Detailed Task Execution Flow

The `customer-helm-install` task follows this detailed execution sequence:

**Step 1: Variable Normalization**
```bash
# Normalize customer and cluster names for consistency
NORMALIZED_CUSTOMER=$(task utils:normalize-name INPUT_NAME="$CUSTOMER_NAME")
NORMALIZED_CLUSTER=$(task utils:normalize-name INPUT_NAME="$CLUSTER_NAME")
```
The `normalize-name` utility converts branch names by replacing `/`, `_`, and `.` with hyphens to match Replicated's slug format.

**Step 2: License ID Retrieval**
```bash
# Get customer license ID using Replicated CLI
REPLICATED_LICENSE_ID=$(task utils:get-customer-license CUSTOMER_NAME="$NORMALIZED_CUSTOMER")
```
The `get-customer-license` utility:
- Normalizes the customer name
- Queries Replicated API: `replicated customer ls --output json`
- Extracts the `installationId` field using jq
- Returns the license ID or exits with error if customer not found

**Step 3: Channel Parameter Resolution**
```bash
# Handle different channel input formats
if [ -n "$CHANNEL_ID" ]; then
  # Convert channel ID to channel slug
  CHANNEL_SLUG=$(task utils:get-channel-slug CHANNEL_ID="$CHANNEL_ID")
  CHANNEL_PARAM="$CHANNEL_SLUG"
elif [ -n "$CHANNEL_SLUG" ]; then
  # Normalize provided channel slug
  NORMALIZED_CHANNEL_SLUG=$(task utils:normalize-name INPUT_NAME="$CHANNEL_SLUG")
  CHANNEL_PARAM="$NORMALIZED_CHANNEL_SLUG"
else
  # Use default channel
  CHANNEL_PARAM=""
fi
```

**Step 4: Kubeconfig File Resolution**
```bash
# Determine kubeconfig file path
KUBECONFIG_FILE=$(task utils:resolve-kubeconfig CLUSTER_NAME="$NORMALIZED_CLUSTER")
```
The task automatically resolves the kubeconfig path based on cluster name or uses provided path.

**Step 5: Helm Installation**
```bash
# Deploy using helm-install task with Replicated environment
task helm-install \
  HELM_ENV=replicated \
  REPLICATED_LICENSE_ID="$REPLICATED_LICENSE_ID" \
  CHANNEL="$CHANNEL_PARAM" \
  KUBECONFIG_FILE="$KUBECONFIG_FILE" \
  CLUSTER_NAME="$NORMALIZED_CLUSTER"
```

#### Helm-Install Task Breakdown

The `helm-install` task performs the actual deployment:

**Step 1: Cluster Validation**
```bash
# Verify cluster exists and get cluster ID
CLUSTER_ID=$(replicated cluster ls --output json | jq -r '.[] | select(.name == "$CLUSTER_NAME") | .id')
if [ -z "$CLUSTER_ID" ]; then
  echo "Error: Could not find cluster with name $CLUSTER_NAME"
  exit 1
fi
```

**Step 2: Port Configuration**
```bash
# Get exposed URLs for the application
ENV_VARS=$(task utils:port-operations OPERATION=getenv CLUSTER_NAME=$CLUSTER_NAME)
```
The `port-operations` utility:
- Retrieves the cluster ID
- Queries exposed ports: `replicated cluster port ls $CLUSTER_ID --output json`
- Extracts the HTTPS hostname for `TF_EXPOSED_URL`
- Returns environment variables for helmfile

**Step 3: Helmfile Deployment**
```bash
# Deploy with Replicated environment variables
eval "KUBECONFIG='$KUBECONFIG_FILE' \
  HELMFILE_ENVIRONMENT='replicated' \
  REPLICATED_APP='$APP_SLUG' \
  REPLICATED_LICENSE_ID='$REPLICATED_LICENSE_ID' \
  CHANNEL='$CHANNEL' \
  $ENV_VARS helmfile sync --wait"
```

#### Key Environment Variables Set

The deployment sets these critical environment variables:

- **`KUBECONFIG`**: Path to cluster kubeconfig file
- **`HELMFILE_ENVIRONMENT`**: Set to "replicated" for Replicated registry
- **`REPLICATED_APP`**: Application slug (e.g., "wg-easy-cre")
- **`REPLICATED_LICENSE_ID`**: Customer's license ID for authentication
- **`CHANNEL`**: Channel slug for release selection
- **`TF_EXPOSED_URL`**: HTTPS hostname for external access

#### Dependencies and Prerequisites

The `customer-helm-install` task depends on:
- **`setup-kubeconfig`**: Ensures kubeconfig is available and valid
- **`cluster-ports-expose`**: Exposes required ports (HTTPS on 30443)
- **`utils:get-customer-license`**: Retrieves customer license ID
- **`utils:normalize-name`**: Normalizes naming conventions
- **`utils:port-operations`**: Manages port exposure and URL retrieval

#### Utility Functions Breakdown

**`utils:normalize-name`**
```bash
# Converts branch names to Replicated-compatible slugs
echo "feature/new-ui" | tr '/_.' '-'
# Result: "feature-new-ui"
```

**`utils:get-customer-license`**
```bash
# Queries Replicated API for customer license ID
replicated customer ls --output json | \
  jq -r '.[] | select(.name == "customer-name") | .installationId'
```

**`utils:port-operations`**
```bash
# For getenv operation: retrieves exposed HTTPS URL
replicated cluster port ls $CLUSTER_ID --output json | \
  jq -r '.[] | select(.upstream_port == 30443) | .hostname'
```

**`utils:get-channel-slug`**
```bash
# Converts channel ID to channel slug for helmfile
replicated channel ls --app $APP_SLUG --output json | \
  jq -r '.[] | select(.id == "$CHANNEL_ID") | .name'
```

#### Error Handling and Validation

The task includes comprehensive error handling:

1. **Customer Validation**: Exits if customer not found with available customer list
2. **Cluster Validation**: Exits if cluster doesn't exist or is not accessible
3. **License Validation**: Ensures license ID is retrieved before deployment
4. **Port Validation**: Verifies HTTPS port is exposed before deployment
5. **Channel Validation**: Handles missing or invalid channel parameters gracefully

### 4. Helmfile Configuration

The deployment uses a `helmfile.yaml.gotmpl` template that configures:

- **OCI Registry URLs**: Points to Replicated's registry
- **Authentication**: Uses license ID as credentials
- **Image Proxying**: Routes container images through Replicated's proxy
- **Environment Variables**: Sets up Replicated-specific configuration

```yaml
environments:
  replicated:
    values:
      - app: '$REPLICATED_APP'
      - channel: '$CHANNEL'
      - username: '$REPLICATED_LICENSE_ID'
      - password: '$REPLICATED_LICENSE_ID'
      - chartSources:
          wgEasy: 'oci://registry.replicated.com/$REPLICATED_APP/$CHANNEL/wg-easy'
```

## Test Matrix

The workflow tests across multiple Kubernetes environments:

### Supported Distributions
- **k3s**: Lightweight Kubernetes distribution
- **EKS**: Amazon Elastic Kubernetes Service (when available)

### Test Versions
- **k3s**: v1.30.8, v1.31.10, v1.32.6
- **Node Configuration**: Single-node clusters
- **Instance Type**: r1.small
- **Timeout**: 15 minutes per test
- **Parallel Execution**: Up to 3 tests simultaneously

### Resource Configuration
- **Disk Size**: 50GB
- **TTL**: 4 hours (6 hours for EKS)
- **Resource Priority**: High for k3s, medium for others

## Validation and Testing

### Pre-deployment Checks
- Helm chart validation
- Taskfile syntax validation
- Cluster readiness verification
- Node availability checks

### Post-deployment Tests
- Basic application functionality tests
- Distribution-specific validation
- Resource utilization monitoring
- Performance metrics collection

### Error Handling
- Retry logic for cluster creation
- Graceful handling of kubeconfig retrieval
- Comprehensive error logging
- Debug artifact collection on failure

## Cleanup Process

A separate cleanup workflow (`wg-easy-pr-cleanup.yaml`) runs when PRs are closed:

### Cleanup Actions
- Delete test clusters
- Remove customer resources
- Clean up channels and releases
- Archive cleanup logs

### Cleanup Triggers
- Pull request closure
- Manual workflow dispatch
- Automatic resource expiration (TTL-based)

## Environment Variables

### Required Secrets
- `WG_EASY_REPLICATED_API_TOKEN`: Replicated API token for authentication
- `WG_EASY_REPLICATED_APP`: Replicated application slug

### Configuration Variables
- `HELM_VERSION`: Helm version to use (default: 3.17.3)
- `KUBECTL_VERSION`: kubectl version to use (default: v1.30.0)

## Monitoring and Debugging

### Log Collection
- Workflow logs are preserved for 7 days
- Debug artifacts are uploaded on failure
- Cleanup logs are archived for 3 days

### Performance Metrics
- Cluster creation time
- Application deployment time
- Resource utilization
- Test execution duration

### Common Issues and Solutions

1. **Cluster Creation Failures**
   - Check API token permissions
   - Verify resource quotas
   - Review cluster naming conflicts

2. **Kubeconfig Issues**
   - Ensure cluster is in "running" state
   - Wait for API server readiness
   - Verify network connectivity

3. **Deployment Failures**
   - Check chart dependencies
   - Verify image availability
   - Review resource requirements

## Best Practices

### Development Workflow
1. Create feature branches from main
2. Make changes in the wg-easy application
3. Push changes to trigger CI validation
4. Monitor workflow execution
5. Address any test failures
6. Merge after successful validation

### Resource Management
- Use descriptive branch names for better resource identification
- Monitor cluster TTL to prevent resource waste
- Clean up resources promptly after testing

### Troubleshooting
- Check workflow logs for detailed error information
- Use debug artifacts for post-mortem analysis
- Verify Replicated CLI configuration and permissions

## Integration with Replicated Platform

The CI workflow demonstrates best practices for:
- **Multi-environment testing**: Validates across different Kubernetes distributions
- **Automated deployment**: Uses Replicated's platform for consistent deployments
- **Resource lifecycle management**: Proper creation and cleanup of test resources
- **Quality assurance**: Comprehensive testing before merging changes

This CI/CD pipeline ensures that wg-easy maintains high quality and compatibility across different Kubernetes environments while providing developers with fast feedback on their changes.
