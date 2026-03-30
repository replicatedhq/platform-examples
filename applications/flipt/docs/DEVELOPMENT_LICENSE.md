# Development License Guide

This guide explains how to obtain and configure a Replicated development license for local testing of Flipt.

## Why a License is Required

Flipt integrates with Replicated's SDK to provide:
- Admin console integration
- Preflight checks
- Support bundle generation
- License enforcement
- Automated updates

The Replicated SDK requires a valid license to function, even in development environments.

## Prerequisites

### 1. Replicated CLI

Install the Replicated CLI:

```bash
# macOS
brew install replicatedhq/replicated/cli

# Linux/macOS (alternative)
curl -s https://api.github.com/repos/replicatedhq/replicated/releases/latest | \
  grep "browser_download_url.*$(uname -s)_$(uname -m)" | \
  cut -d '"' -f 4 | \
  xargs curl -L -o replicated
chmod +x replicated
sudo mv replicated /usr/local/bin/
```

Verify installation:
```bash
replicated version
```

### 2. Replicated API Token

1. Log in to [vendor.replicated.com](https://vendor.replicated.com)
2. Navigate to **Settings** > **Service Accounts**
3. Click **Create Service Account**
4. Copy the API token
5. Export it:
   ```bash
   export REPLICATED_API_TOKEN=your-token-here
   ```

## Creating a Development License

### Step 1: Create a Development Customer

Pick a customer name you'll reuse in subsequent steps:

```bash
CUSTOMER_NAME="dev-$(whoami)"

replicated customer create \
  --app flipt \
  --name "$CUSTOMER_NAME" \
  --channel Unstable \
  --license-type dev
```

### Step 2: Download the License

```bash
replicated customer download-license \
  --app flipt \
  --customer "$CUSTOMER_NAME" \
  --output license.yaml
```

### Step 3: Install Flipt with the License

```bash
# Update chart dependencies first
make update-deps

# Install with the downloaded license file
helm install flipt ./chart \
  --namespace flipt \
  --create-namespace \
  --set-file replicated.license=license.yaml \
  --wait \
  --timeout 15m
```

## License Management

### View Your Licenses

```bash
replicated customer ls
```

### Delete a License

```bash
replicated customer rm --customer "customer-name"

# Or delete all dev licenses
replicated customer ls --output json | \
  jq -r '.[] | select(.licenseType == "dev") | .name' | \
  xargs -I {} replicated customer rm --customer {}
```

### License Expiry

Development licenses may have expiration dates. If your license expires, create a new one following the steps above.

## Troubleshooting

### Error: "replicated: command not found"

Install the Replicated CLI (see Prerequisites above).

### Error: "unauthorized: authentication required"

Your API token may be invalid or expired:
1. Verify token: `replicated api version`
2. Generate new token at vendor.replicated.com
3. Export new token: `export REPLICATED_API_TOKEN=new-token`

### Error: "license not found"

The license may not be set correctly:
```bash
# Check the current helm values
helm get values flipt --namespace flipt

# Re-download and apply the license
replicated customer download-license \
  --app flipt \
  --customer "$CUSTOMER_NAME" \
  --output license.yaml

helm upgrade flipt ./chart \
  --namespace flipt \
  --set-file replicated.license=license.yaml
```

### Pod Still Crashing

Check Replicated SDK logs:
```bash
kubectl logs -l app=replicated -n flipt
```

Common issues:
- License ID is incorrect
- License has expired
- Network issues accessing Replicated services

## CI/CD Integration

For automated testing in CI/CD:

```yaml
# Example GitHub Actions
- name: Create Dev Customer
  env:
    REPLICATED_API_TOKEN: ${{ secrets.REPLICATED_API_TOKEN }}
  run: |
    CUSTOMER_NAME="ci-${{ github.run_id }}"
    echo "CUSTOMER_NAME=$CUSTOMER_NAME" >> $GITHUB_ENV

    replicated customer create \
      --app flipt \
      --name "$CUSTOMER_NAME" \
      --channel Unstable \
      --license-type dev

    replicated customer download-license \
      --app flipt \
      --customer "$CUSTOMER_NAME" \
      --output license.yaml

- name: Install Flipt
  run: |
    make update-deps
    helm install flipt ./chart \
      --namespace flipt \
      --create-namespace \
      --set-file replicated.license=license.yaml \
      --wait --timeout 15m

- name: Cleanup Customer
  if: always()
  env:
    REPLICATED_API_TOKEN: ${{ secrets.REPLICATED_API_TOKEN }}
  run: |
    replicated customer rm --customer "$CUSTOMER_NAME"
```

## Resources

- [Replicated CLI Documentation](https://docs.replicated.com/reference/replicated-cli)
- [Customer Management](https://docs.replicated.com/vendor/customers-managing)
- [License Types](https://docs.replicated.com/vendor/licenses-about)
