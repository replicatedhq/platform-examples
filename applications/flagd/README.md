# flagd — OpenFeature Feature Flag Evaluation Daemon

[flagd](https://flagd.dev) is an OpenFeature-compliant feature flag evaluation daemon. It reads flag definitions from a JSON configuration file typically managed as a ConfigMap in Kubernetes and exposes them over gRPC and HTTP for application-side evaluation.

## Why flagd Demonstrates the ConfigMap Hash Pattern

flagd loads its flag definitions from a file at startup (`--uri file:/etc/flagd/flags.json`). In Kubernetes, this file is mounted from a ConfigMap. When an operator changes flag definitions — for example, increasing a rollout percentage from 10% to 50% — the running pods continue serving stale evaluations until restarted. Without a restart mechanism, the updated configuration has no effect on live traffic.

The [configmap hash rolling update pattern](../../patterns/configmap-hash-rolling-update/) solves this by adding a `checksum/config` annotation to the pod template that hashes the rendered ConfigMap. When flag definitions change, the hash changes, Kubernetes sees a new pod spec, and a rolling update is triggered automatically.

## Real-World Scenario

A platform team runs flagd as a centralized feature flag service. The `new-checkout-flow` flag is configured with a 10% fractional rollout. After validating metrics, the team updates the rollout to 50% by changing the weight in `values.yaml`. Without the checksum annotation, pods keep evaluating at 10% — stale behavior with real business impact. With it, `helm upgrade` triggers a rolling update and all pods serve the updated 50% rollout.

## Chart Structure

```
charts/flagd/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── _helpers.tpl
    ├── configmap.yaml        # Flag definitions as JSON
    ├── deployment.yaml       # checksum/config annotation triggers rolling updates
    ├── service.yaml          # Exposes gRPC (8013) and HTTP (8016)
    └── serviceaccount.yaml
```

## Prerequisites

- [minikube](https://minikube.sigs.k8s.io/docs/start/)
- [Helm](https://helm.sh/docs/intro/install/) v3+
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- GNU Make

## Local Demo Walkthrough

The demo has two acts: **`make problem`** and **`make solution`**. Each is self-contained — it deploys, evaluates flags, upgrades the config, evaluates again, and cleans up.

A Makefile automates the full flow. Run `make help` from this directory to see all targets.

### 1. Start a minikube cluster

```bash
make cluster
```

### 2. `make problem` — without the checksum annotation

Each demo can run end-to-end as a single command, or be stepped through one stage at a time for a live presentation.

**Full run:**

```bash
make problem
```

**Step-by-step:**

```bash
make problem-step1     # Deploy, evaluate all flags
make problem-step2     # Upgrade: rollout to 50%, enable dark-mode & maintenance
make problem-step3     # Evaluate again — all flags still return old values (stale!)
make problem-teardown  # Clean up
```

What you'll see:
1. Deploys flagd **without** the checksum annotation
2. Evaluates all three flags — `new-checkout-flow` at 10%, `dark-mode` off, `maintenance-mode` off
3. Upgrades the config — rollout to 50/50, enable dark-mode and maintenance-mode
4. Evaluates again — **all still return old values**, the pod is serving stale config
5. The ConfigMap *was* updated but the pod was *not* restarted

### 3. `make solution` — with the checksum annotation

**Full run:**

```bash
make solution
```

**Step-by-step:**

```bash
make solution-step1     # Deploy with checksum, evaluate all flags
make solution-step2     # Upgrade — rolling update occurs
make solution-step3     # Evaluate again — all flags return updated values (fresh!)
make solution-teardown  # Clean up
```

What you'll see:
1. Deploys flagd **with** the checksum annotation (the default)
2. Evaluates all three flags — same initial state
3. Upgrades the config — same changes
4. A **rolling update** is triggered — new pod, new checksum
5. Evaluates again — `dark-mode` and `maintenance-mode` now return **`true`**, rollout shows updated config

### 4. Full cleanup

```bash
make clean
```

### Querying flags manually

You can also evaluate flags individually at any point while a port-forward is active:

```bash
make eval-flags              # Evaluate all flags
make eval-flag-checkout      # Just new-checkout-flow
make eval-flag-darkmode      # Just dark-mode
make eval-flag-maintenance   # Just maintenance-mode
```

## Quick Reference

| Target | Description |
|---|---|
| `make cluster` | Start minikube cluster |
| `make clean` | Uninstall chart and delete minikube cluster |
| **Problem (no pattern)** | |
| `make problem` | Full run: deploy, upgrade, evaluate (stale) |
| `make problem-step1` | Deploy WITHOUT checksum, evaluate all flags |
| `make problem-step2` | Upgrade all flags |
| `make problem-step3` | Evaluate — all flags still return old values |
| `make problem-teardown` | Clean up |
| **Solution (with pattern)** | |
| `make solution` | Full run: deploy, upgrade, rolling update, evaluate (fresh) |
| `make solution-step1` | Deploy WITH checksum, evaluate all flags |
| `make solution-step2` | Upgrade all flags — rolling update occurs |
| `make solution-step3` | Evaluate — all flags return updated values |
| `make solution-teardown` | Clean up |
| **Helpers** | |
| `make status` | Show pods, service, and flag definitions |
| `make checksum` | Show the checksum/config annotation on pods |
| `make pod-age` | Show pod names and ages |
| **Flag evaluation** | |
| `make port-forward` | Start port-forward to flagd HTTP API |
| `make port-forward-stop` | Stop the port-forward |
| `make eval-flags` | Evaluate all flags via OFREP HTTP API |
| `make eval-flag-checkout` | Evaluate new-checkout-flow |
| `make eval-flag-darkmode` | Evaluate dark-mode |
| `make eval-flag-maintenance` | Evaluate maintenance-mode |
| **CMX (Replicated)** | |
| `make cmx-cluster-create` | Create a CMX cluster |
| `make cmx-cluster-kubeconfig` | Fetch kubeconfig for the CMX cluster |
| `make cmx-cluster-list` | List CMX clusters |
| `make cmx-cluster-rm` | Delete the CMX cluster |
| `make cmx-clean` | Uninstall chart and delete CMX cluster |

## Testing with Replicated Compatibility Matrix (CMX)

You can run this same demo on a real multi-distribution Kubernetes cluster using [Replicated Compatibility Matrix](https://docs.replicated.com/vendor/testing-how-to) instead of minikube.

### Prerequisites

- [Replicated CLI](https://docs.replicated.com/reference/replicated-cli-installing) installed and authenticated
- `jq` installed
- `REPLICATED_API_TOKEN` set in your environment (or logged in via `replicated login`)

### 1. Create a CMX cluster

```bash
make cmx-cluster-create
```

This creates a single-node k3s v1.31 cluster with a 4-hour TTL by default. Override as needed:

```bash
make cmx-cluster-create CMX_DISTRIBUTION=kind CMX_K8S_VERSION=1.32 CMX_TTL=2h
```

### 2. Wait for the cluster to be ready

```bash
make cmx-cluster-list
```

Wait until the cluster status shows `running`.

### 3. Fetch the kubeconfig

```bash
make cmx-cluster-kubeconfig
```

### 4. Verify cluster access

```bash
kubectl get nodes
```

### 5. Run the demo

With the CMX kubeconfig active, the demo targets work exactly as they do locally:

**Problem (stale config — no checksum):**

```bash
make problem-step1
make problem-step2
make problem-step3
make problem-teardown
```

**Solution (rolling update — with checksum):**

```bash
make solution-step1
make solution-step2
make solution-step3
make solution-teardown
```

### 6. Clean up

Remove the chart and delete the CMX cluster:

```bash
make cmx-clean
```

Or just delete the cluster (if you already uninstalled the chart):

```bash
make cmx-cluster-rm
```

### CMX configuration defaults

| Variable | Default | Description |
|---|---|---|
| `CMX_CLUSTER_NAME` | `flagd-demo` | Cluster name |
| `CMX_DISTRIBUTION` | `k3s` | Kubernetes distribution (`k3s`, `kind`, `eks`, etc.) |
| `CMX_K8S_VERSION` | `1.32.13` | Kubernetes version |
| `CMX_INSTANCE_TYPE` | `r1.small` | Instance type |
| `CMX_NODE_COUNT` | `1` | Number of nodes |
| `CMX_DISK_SIZE` | `50` | Disk size in GB |
| `CMX_TTL` | `4h` | Time-to-live before auto-deletion |

## Pattern Reference

See [configmap-hash-rolling-update](../../patterns/configmap-hash-rolling-update/) for full details on how the checksum annotation pattern works.
