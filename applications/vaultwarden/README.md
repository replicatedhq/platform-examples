# Vaultwarden with kURL

This example demonstrates how to distribute [Vaultwarden](https://github.com/dani-garcia/vaultwarden) (an unofficial Bitwarden-compatible password manager) as a self-hosted application using [Replicated KOTS](https://docs.replicated.com/intro-replicated) and [kURL](https://kurl.sh), and how to test it using [Compatibility Matrix (CMX)](https://docs.replicated.com/vendor/testing-about).

## What is kURL?

kURL is a Replicated open-source project that creates custom Kubernetes installers. It lets you define a Kubernetes distribution as a YAML spec — choosing specific versions of the container runtime, networking, storage, ingress, and other add-ons — and then install that entire stack on a bare Linux machine with a single command.

This is useful when your customers:
- Run on bare metal or VMs without an existing Kubernetes cluster
- Need an air-gapped installation
- Want a single-command install experience

The kURL installer spec for this example is in [`kots/kurl-installer.yaml`](kots/kurl-installer.yaml). It provisions:

| Add-on | Purpose |
|--------|---------|
| **Kubernetes 1.29** | Container orchestration via kubeadm |
| **Containerd** | Container runtime |
| **Flannel** | Pod networking (CNI) |
| **OpenEBS** | Local persistent volumes for Vaultwarden data |
| **Contour** | Ingress controller (Envoy-based) |
| **MinIO** | Object storage for KOTS snapshots/backups |
| **Registry** | Local Docker registry for air-gap image storage |
| **KOTS Admin Console** | Web UI for application configuration and lifecycle |

You can customize the add-on selection and versions at [kurl.sh/add-ons](https://kurl.sh/add-ons).

## How It All Fits Together

```
┌─────────────────────────────────────────────────────────────┐
│  Bare Linux VM                                              │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  kURL-provisioned Kubernetes cluster                  │  │
│  │                                                       │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐  │  │
│  │  │ Vaultwarden │  │ KOTS Admin   │  │ Contour     │  │  │
│  │  │ (your app)  │  │ Console      │  │ (ingress)   │  │  │
│  │  │ port 80     │  │ port 8800    │  │ ports 80/443│  │  │
│  │  └──────┬──────┘  └──────────────┘  └─────────────┘  │  │
│  │         │                                             │  │
│  │  ┌──────┴──────┐  ┌──────────────┐  ┌─────────────┐  │  │
│  │  │ OpenEBS PV  │  │ MinIO        │  │ Registry    │  │  │
│  │  │ (vault data)│  │ (snapshots)  │  │ (air-gap)   │  │  │
│  │  └─────────────┘  └──────────────┘  └─────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

The KOTS Admin Console provides a config screen (defined in [`kots/kots-config.yaml`](kots/kots-config.yaml)) where the end-user sets their domain, admin token, database type, and SMTP settings — without needing to know Helm or YAML.

## Prerequisites

1. A [Replicated Vendor Portal](https://vendor.replicated.com/signup) account
2. The [Replicated CLI](https://docs.replicated.com/reference/replicated-cli-installing) (`replicated`)
3. `helm` CLI (v3.12+)
4. A release channel and customer configured in the Vendor Portal with kURL entitlement
5. CMX credits (for testing with Compatibility Matrix)

## Step-by-Step: Build, Release, and Test

### Step 1 — Package the Helm chart and create a release

This packages the Vaultwarden Helm chart into a `.tgz`, copies it into the `kots/` directory alongside the KOTS manifests, and pushes everything to the Replicated Vendor Portal as a new release on the Unstable channel.

```bash
cd applications/vaultwarden

# Pull the Replicated SDK dependency
make update-dependencies

# Package the chart and create a Replicated release
make release
```

**What happens under the hood:**
1. `helm package` builds `vaultwarden-1.0.0.tgz`
2. The `chartVersion` in `kots/vaultwarden-chart.yaml` is updated to match
3. `replicated release create` uploads the entire `kots/` directory — including the chart archive, the kURL installer spec, config screen, preflight checks, and support bundle spec — as a single release

### Step 2 — Promote the release and prepare a customer

In the Vendor Portal:

1. **Promote** the release from Unstable to a test channel (or create a new channel)
2. **Create a customer** (or use an existing one) and assign them to the channel
3. Under the customer settings, **enable kURL** as an installation method
4. **Copy the customer's license ID** — you'll need it to create the CMX cluster

### Step 3 — Create a kURL cluster with CMX

CMX provisions a bare VM and runs the kURL installer automatically using your installer spec and the customer's license:

```bash
make cmx-create LICENSE_ID=<your-license-id>
```

This is equivalent to:
```bash
replicated cluster create \
    --distribution kurl \
    --instance-type r1.xlarge \
    --disk 100 \
    --license-id <license-id> \
    --ttl 4h \
    --name vaultwarden-kurl
```

Monitor progress:
```bash
make cmx-status
```

The cluster takes a few minutes to provision. kURL downloads and installs all the add-ons defined in `kurl-installer.yaml`, then installs the KOTS Admin Console.

### Step 4 — Access the KOTS Admin Console

Once the cluster shows `running`, expose the admin console port:

```bash
make cmx-expose-admin CLUSTER_ID=<cluster-id>
```

This gives you a public URL to the KOTS Admin Console (port 8800). Open it in your browser and:

1. Set an admin password
2. Upload the customer license file (download it from the Vendor Portal)
3. **Preflight checks run automatically** — these validate the cluster meets minimum requirements (Kubernetes version, CPU, memory, storage class). The checks are defined in [`kots/kots-preflight.yaml`](kots/kots-preflight.yaml).
4. **Configure the application** using the config screen:
   - Set the domain where Vaultwarden will be reachable
   - Optionally set an admin token for the `/admin` panel
   - Choose SQLite (default) or PostgreSQL for the database
   - Optionally configure SMTP for email notifications
5. **Deploy** — KOTS renders the Helm chart with your config values (via the mappings in [`kots/vaultwarden-chart.yaml`](kots/vaultwarden-chart.yaml)) and installs it

### Step 5 — Verify the deployment

You can shell into the cluster to inspect resources:

```bash
make cmx-shell CLUSTER_ID=<cluster-id>

# Inside the cluster shell:
kubectl get pods
kubectl get svc
kubectl logs deployment/vaultwarden
```

Or run the automated smoke tests (from your local machine with kubeconfig):

```bash
make cmx-kubeconfig CLUSTER_ID=<cluster-id>
export KUBECONFIG=$(pwd)/kubeconfig
make test-smoke
```

The smoke tests verify:
- The `/alive` health endpoint responds
- The web vault UI is being served
- The `/api/config` Bitwarden-compatible API endpoint works

### Step 6 — Clean up

```bash
make cmx-delete CLUSTER_ID=<cluster-id>
```

## Understanding the KOTS Manifests

The `kots/` directory contains everything Replicated needs to distribute your application:

| File | Kind | Purpose |
|------|------|---------|
| `kots-app.yaml` | `Application` | App metadata (name, icon, status informers) |
| `kots-config.yaml` | `Config` | Defines the configuration screen shown to users |
| `vaultwarden-chart.yaml` | `HelmChart` | Maps config values → Helm chart values |
| `kurl-installer.yaml` | `Installer` | kURL add-on selection and versions |
| `kots-preflight.yaml` | `Preflight` | Pre-install cluster validation checks |
| `kots-support-bundle.yaml` | `SupportBundle` | Diagnostic collection for troubleshooting |
| `k8s-app.yaml` | `Application` (k8s) | Kubernetes Application CRD metadata |
| `vaultwarden-1.0.0.tgz` | (chart archive) | Generated by `make package-and-update` |

### Config → Helm value flow

The KOTS config screen collects user input. The `HelmChart` CR maps those inputs to Helm values using Replicated template functions:

```
User enters "https://vault.acme.com" in the Domain field
    ↓
kots-config.yaml defines: name: domain, type: text
    ↓
vaultwarden-chart.yaml maps: vaultwarden.domain: repl{{ ConfigOption "domain" }}
    ↓
Helm renders deployment.yaml with env DOMAIN=https://vault.acme.com
```

### Preflight checks

Preflight checks (in `kots-preflight.yaml`) run before installation to catch problems early:
- Kubernetes version ≥ 1.26
- At least 2 CPU cores
- At least 4Gi memory
- A default StorageClass exists

These use the [Troubleshoot](https://troubleshoot.sh) framework. If a check fails, the user sees the failure message in the admin console with guidance on how to fix it.

### Support bundles

When something goes wrong, users can generate a support bundle from the admin console. The spec in `kots-support-bundle.yaml` collects cluster info, resources, Vaultwarden logs, and runs analyzers to identify common issues.

## Local Development (without CMX)

You can develop and test the Helm chart locally without Replicated:

```bash
# Lint the chart
make test-lint

# Install on any Kubernetes cluster (Replicated SDK disabled)
make test-install

# Run smoke tests
make test-smoke

# Full sequence
make test-all
```

## File Structure

```
vaultwarden/
├── Makefile                              # Build, release, CMX, and test targets
├── README.md
├── charts/
│   └── vaultwarden/                      # Helm chart
│       ├── Chart.yaml                    # Chart metadata + Replicated SDK dependency
│       ├── values.yaml                   # Default values
│       └── templates/
│           ├── _helpers.tpl              # Template helpers (name, labels, DB URL)
│           ├── deployment.yaml           # Vaultwarden Deployment
│           ├── service.yaml              # ClusterIP Service
│           ├── secret.yaml              # Database URL, admin token, SMTP password
│           ├── pvc.yaml                  # Persistent storage for /data
│           ├── ingress.yaml              # Optional Ingress
│           └── NOTES.txt                 # Post-install instructions
├── kots/                                 # Replicated / KOTS manifests
│   ├── kots-app.yaml                     # Application metadata
│   ├── kots-config.yaml                  # Config screen definition
│   ├── vaultwarden-chart.yaml            # HelmChart CR (config → values mapping)
│   ├── kurl-installer.yaml               # kURL embedded installer spec
│   ├── kots-preflight.yaml               # Pre-install validation checks
│   ├── kots-support-bundle.yaml          # Diagnostic collection spec
│   └── k8s-app.yaml                      # Kubernetes Application CR
└── tests/
    ├── helm/
    │   └── ci-values.yaml                # Minimal values for CI/test installs
    ├── requirements.txt                  # Python test dependencies
    └── smoke_test.py                     # Automated health + API checks
```
