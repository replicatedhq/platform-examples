# License Validation Demo

A demo application that showcases how to consume **custom license fields** from a Replicated license, validate their **cryptographic signatures**, and tie license field values to **observable application behavior**.

## What This Demonstrates

1. **Custom license field consumption** — The app reads `edition` (string) and `seat_count` (integer) fields from the Replicated SDK at runtime
2. **Signature validation** — Each license field's RSA-PSS/SHA-256 signature is verified against the application's public key to detect tampering
3. **Behavioral enforcement** — License fields visibly control the application:
   - **Edition tier** changes the entire UI theme (blue = Community, amber = Trial, green = Enterprise) and gates feature access
   - **Seat count** renders a usage meter with color-coded warnings when approaching or exceeding the limit
   - **Invalid signatures** lock all features and display an error banner
   - **Expired licenses** lock all features

## Custom License Fields to Configure

In the [Replicated Vendor Portal](https://vendor.replicated.com), create these custom license fields for your application:

| Field Name   | Type    | Description                                      | Example Values                   |
|-------------|---------|--------------------------------------------------|----------------------------------|
| `edition`    | String  | Controls UI theme and feature gating             | `community`, `trial`, `enterprise` |
| `seat_count` | Integer | Maximum number of licensed seats                 | `10`, `50`, `100`                |

### Setting Up License Fields

1. Go to **Settings > Custom License Fields** in the Vendor Portal
2. Click **Create a custom field**
3. Add `edition` as a **String** field with default value `community`
4. Add `seat_count` as an **Integer** field with default value `10`
5. When creating or editing customer licenses, set these fields to the desired values

## Signature Validation Approach

The application validates license field signatures using the following mechanism:

1. The Replicated SDK subchart runs alongside the application and exposes a REST API
2. The app queries `GET /api/v1/license/fields` which returns each custom field with its `signature.v1` value
3. For each field, the app:
   - Extracts the string representation of the field value
   - Computes a SHA-256 hash
   - Verifies the hash against the base64-decoded signature using RSA-PSS with the application's public key
4. If any signature fails validation, all features are locked

### Getting the Application Public Key

1. In the Vendor Portal, go to **Settings**
2. Copy the **Application Public Key** (RSA PEM format)
3. Provide it via the KOTS admin console config or the `appPublicKey` Helm value

## Deployment

### Prerequisites

- Kubernetes 1.25+
- Helm 3.x
- [Replicated CLI](https://docs.replicated.com/reference/replicated-cli-overview) (for releases)
- [Task](https://taskfile.dev/) (optional, for automation)

### Local Development

```bash
# Build the Go binary and run locally (shows SDK error state)
task go:run

# Build Docker image
task docker:build

# Install to a local cluster without the Replicated SDK
task helm:install-local
```

### Creating a Replicated Release

```bash
# Update Helm dependencies (fetches the Replicated SDK subchart)
task helm:update-deps

# Lint the chart
task helm:lint

# Create a release and promote to Unstable
task release-create

# Or target a specific channel
task release-create CHANNEL=Beta
```

### KOTS Installation

1. Install via the KOTS admin console
2. Configure the **Simulated Seat Usage** (default: 12)
3. Optionally paste your **Application Public Key** to enable signature validation
4. Deploy the application

The admin console will forward port 8888 to the application (configurable in `kots-app.yaml`).

## Demo Walkthrough (Vendor Portal + Compatibility Matrix)

This walks through the full demo end-to-end: setting up the app in the Vendor Portal, deploying to a Compatibility Matrix cluster, and observing license-driven behavior.

### Prerequisites

- [Replicated CLI](https://docs.replicated.com/reference/replicated-cli-overview) authenticated (`replicated login`)
- Docker (for building the app image)

### Step 1: Create the Application in the Vendor Portal

1. Go to [vendor.replicated.com](https://vendor.replicated.com) and create a new application named `license-validation`
2. Note your **app slug** (e.g., `license-validation`) — you'll use it with the CLI

Set the app slug for subsequent commands:

```bash
export REPLICATED_APP=license-validation
```

### Step 2: Create Custom License Fields

1. In the Vendor Portal, go to **License Fields**
2. Create two fields:

| Field Name   | Type    | Default        |
|-------------|---------|----------------|
| `edition`    | String  | `community`    |
| `seat_count` | Integer | `10`           |

### Step 3: Build and Push the Application Image

```bash
# Build the Docker image
docker build --platform linux/amd64,linux/arm64 -t ttl.sh/license-validation:2h .

# Push to ttl.sh (ephemeral registry, good for demos)
docker push ttl.sh/license-validation:2h
```

> Update `charts/license-validation/values.yaml` to use `ttl.sh/license-validation` as the image repository and `2h` as the tag, or pass these as overrides in the HelmChart CR.

### Step 4: Create a Release

```bash
# Fetch the Replicated SDK subchart
task helm:update-deps

# Package the chart and create a release
task release-create CHANNEL=Unstable
```

### Step 5: Create a Customer

```bash
replicated customer create \
  --name "Demo Customer" \
  --channel Unstable \
  --type dev \
  --expires-in 720h
```

Now edit the customer's license in the Vendor Portal to set:
- `edition` = `enterprise`
- `seat_count` = `50`

### Step 6: Create a Compatibility Matrix Cluster

```bash
replicated cluster create \
  --name license-validation-demo \
  --distribution k3s \
  --version 1.33 \
  --disk 50 \
  --instance-type r1.small \
  --ttl 4h
```

Wait for the cluster to be ready:

```bash
replicated cluster ls
```

### Step 7: Get Kubeconfig

```bash
replicated cluster kubeconfig license-validation-demo \
  --output-path ./demo.kubeconfig

export KUBECONFIG=./demo.kubeconfig
kubectl get nodes  # verify connectivity
```

### Step 8: Install the Application

**Option A: Helm install (direct)**

```bash
# Log in to the Replicated registry using the customer's license ID
LICENSE_ID=$(replicated customer ls --output json | jq -r '.[] | select(.name == "Demo Customer") | .installationId')

helm registry login registry.replicated.com \
  --username "$LICENSE_ID" \
  --password "$LICENSE_ID"

helm install license-validation \
  oci://registry.replicated.com/$REPLICATED_APP/unstable/license-validation \
  --namespace license-validation \
  --create-namespace
```

**Option B: KOTS install**

```bash
# Download the customer license file
replicated customer download-license --customer "Demo Customer" > ./license.yaml

# Install via KOTS admin console
kubectl kots install $REPLICATED_APP/unstable \
  --namespace license-validation \
  --shared-password password \
  --license-file ./license.yaml
```

### Step 9: Access the Dashboard

```bash
kubectl port-forward svc/license-validation 8888:80 -n license-validation
```

Open [http://localhost:8888](http://localhost:8888) — you should see:
- Green **Enterprise** badge and theme
- Seat meter showing 12/50 seats used
- All 5 features unlocked

### Step 10: See License Changes in Real Time

Back in the Vendor Portal, edit the customer's license:

1. Change `edition` from `enterprise` to `trial` — refresh the dashboard and watch the theme change to amber, with SSO/Audit/Priority features now locked
2. Change `seat_count` from `50` to `10` — the seat meter turns red showing 12/10 exceeded
3. Change `edition` to `community` — only "Core Dashboard" remains unlocked

The app polls the SDK every 30 seconds, so changes appear within ~30s of saving in the portal.

### Cleanup

```bash
replicated cluster rm license-validation-demo
unset KUBECONFIG
rm -f demo.kubeconfig
```

## Testing the Tampered License Scenario

To see signature validation enforcement in action:

### Method 1: Invalid Public Key

1. Deploy the application with signature validation enabled (paste a valid public key)
2. Verify the dashboard shows "All field signatures verified" with a green checkmark
3. Update the KOTS config with a **different** RSA public key (not the one from your app)
4. The app will detect that signatures don't match and lock all features with a red error banner

### Method 2: No Public Key (Disabled Validation)

1. Deploy without providing a public key
2. The dashboard shows a yellow warning: "No public key configured - signature validation is disabled"
3. Features remain unlocked but signature status is shown as a warning

### Method 3: Change License Fields

1. In the Vendor Portal, change a customer's `edition` from `enterprise` to `community`
2. Watch the dashboard theme change from green to blue and enterprise features lock
3. Change `seat_count` to a value lower than `simulated_seat_usage` to see the seat limit exceeded warning

## Architecture

```
┌──────────────────────────────────────────────────┐
│  Kubernetes Cluster                              │
│                                                  │
│  ┌─────────────────┐    ┌─────────────────────┐  │
│  │  license-        │    │  replicated-sdk     │  │
│  │  validation      │───▶│  (subchart)         │  │
│  │  (Go web app)    │    │  :3000              │  │
│  │  :8080           │    │                     │  │
│  └─────────────────┘    │  GET /api/v1/       │  │
│         │                │    license/info     │  │
│         │                │    license/fields   │  │
│         ▼                └─────────────────────┘  │
│  ┌─────────────────┐                              │
│  │  Service         │                              │
│  │  :80 → :8080     │                              │
│  └─────────────────┘                              │
└──────────────────────────────────────────────────┘
```

The application is a single Go binary with an embedded HTML template. It polls the Replicated SDK every 30 seconds for updated license information.

## File Structure

```
applications/license-validation/
├── README.md                           # This file
├── Dockerfile                          # Multi-stage Go build
├── Taskfile.yaml                       # Build and release automation
├── development-values.yaml             # KOTS ConfigValues for headless install
├── app/
│   ├── go.mod                          # Go module definition
│   └── main.go                         # Application source (server + template)
├── charts/license-validation/
│   ├── Chart.yaml                      # Helm chart with Replicated SDK dependency
│   ├── values.yaml                     # Default Helm values
│   └── templates/
│       ├── _helpers.tpl                # Template helpers (name, labels, SDK address)
│       ├── _preflight.tpl              # Preflight check definitions
│       ├── _supportbundle.tpl          # Support bundle definitions
│       ├── deployment.yaml             # Application deployment
│       ├── service.yaml                # ClusterIP service
│       ├── secret-public-key.yaml      # Public key secret (conditional)
│       ├── replicated-preflight.yaml   # Preflight secret
│       └── replicated-supportbundle.yaml # Support bundle secret
└── kots/
    ├── kots-app.yaml                   # KOTS Application metadata
    ├── kots-config.yaml                # Admin console configuration UI
    └── license-validation-chart.yaml   # HelmChart CR (maps config → Helm values)
```
