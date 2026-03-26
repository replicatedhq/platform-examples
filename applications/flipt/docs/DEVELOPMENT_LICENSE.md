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

## Quick Start

### Option 1: Automated Setup (Recommended)

```bash
# 1. Set up your Replicated API token
export REPLICATED_API_TOKEN=your-token-here

# 2. Run the setup script
./scripts/setup-dev-license.sh

# 3. Load the license
source .replicated/license.env

# 4. Install Flipt
./scripts/install.sh
```

### Option 2: Using Makefile

```bash
# Set up license and install in one command
export REPLICATED_API_TOKEN=your-token-here
make install-with-license
```

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

   Or add to your shell profile (~/.bashrc, ~/.zshrc):
   ```bash
   echo 'export REPLICATED_API_TOKEN=your-token-here' >> ~/.zshrc
   source ~/.zshrc
   ```

## Manual License Setup

If you prefer manual setup or need more control:

### Step 1: Create a Development Customer

```bash
replicated customer create \
  --app flipt \
  --name "dev-$(whoami)-$(date +%s)" \
  --channel Unstable \
  --license-type dev \
  --output json > customer.json
```

### Step 2: Extract License ID

```bash
LICENSE_ID=$(jq -r '.id' customer.json)
echo "License ID: $LICENSE_ID"
```

### Step 3: Save License Configuration

```bash
mkdir -p .replicated
echo "REPLICATED_LICENSE_ID=$LICENSE_ID" > .replicated/license.env
```

### Step 4: Use License

```bash
source .replicated/license.env
./scripts/install.sh
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

Development licenses may have expiration dates. If your license expires:

1. Delete the old license:
   ```bash
   make clean-license
   ```

2. Create a new one:
   ```bash
   ./scripts/setup-dev-license.sh
   ```

## Troubleshooting

### Error: "replicated: command not found"

Install the Replicated CLI (see Prerequisites above).

### Error: "unauthorized: authentication required"

Your API token may be invalid or expired:
1. Verify token: `replicated api version`
2. Generate new token at vendor.replicated.com
3. Export new token: `export REPLICATED_API_TOKEN=new-token`

### Error: "license not found"

The license secret may not be created:
```bash
# Verify secret exists
kubectl get secret replicated-license -n flipt

# Recreate if missing
kubectl create secret generic replicated-license \
  --from-literal=license="$REPLICATED_LICENSE_ID" \
  --namespace flipt
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
- name: Setup Replicated License
  env:
    REPLICATED_API_TOKEN: ${{ secrets.REPLICATED_API_TOKEN }}
  run: |
    ./scripts/setup-dev-license.sh
    source .replicated/license.env

- name: Install Flipt
  run: |
    source .replicated/license.env
    ./scripts/install.sh

- name: Cleanup License
  if: always()
  run: |
    make clean-license
```

## Alternative: Disable Replicated SDK

If you absolutely need to run without a license (not recommended for production testing):

```bash
helm install flipt ./chart \
  --namespace flipt \
  --create-namespace \
  --set replicated.enabled=false
```

**Note:** This disables all Replicated features including support bundles and preflight checks.

## Resources

- [Replicated CLI Documentation](https://docs.replicated.com/reference/replicated-cli)
- [Customer Management](https://docs.replicated.com/vendor/customers-managing)
- [License Types](https://docs.replicated.com/vendor/licenses-about)
