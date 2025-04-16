# Helm Chart Development Workflow

## Objective

Provide engineers with a clear, reproducible workflow for iterative Helm chart development, emphasizing fast feedback loops and easy configuration management. The workflow leverages Terraform, Helm CLI, and automation via `just` and Dagger.

---

## Components

- **n8n** *(local, custom Helm chart)*
- **CloudNativePG (Postgres)** *(remote Helm chart)*
- **Traefik ingress** *(remote Helm chart)*

---

## Key Principles

- **Progressive Complexity** – Start simple, add complexity incrementally.
- **Fast Feedback** – Immediate validation of changes.
- **Reproducibility** – Simple to recreate locally.
- **Modular Configuration** – Clear separation of values per component.
- **Automation** – Minimize repetitive tasks.

---

## Project Repository Structure

```
.
├── charts
│   ├── n8n/             # Custom local Helm chart
│   │   ├── charts/      # Helm chart dependencies
│   └── n8n-values.yaml  # Environment-specific Helm values for n8n for local dev
├── dagger               # Automation logic (chart packaging/releases)
│   ├── main.go          # Main dagger code
├── docs                 # Workflow documentation
│   └── workflow.md      # Workflow guide (this document)
├── memory_bank          # Tracking files for workflow tasks
├── justfile             # Automation tasks (developer-friendly commands)
├── main.tf              # Terraform config for Helm chart releases
```

---

## Prerequisites

- Kubernetes cluster (**k3d recommended**; any valid Kubernetes cluster is acceptable)
- Helm CLI installed
- Terraform CLI installed
- Dagger CLI installed
- `just` command-line runner installed

---

## Workflow Steps

```
just setup
just install
just destroy
```

### just setup
This command will create a Replicated DEV customer, so that we can test integration with Replicated SDK. The newly created customer id + license id will be persisted into `.env` file to be used by other tasks.
It will then run `helm dependency update` to download subcharts used by `n8n` chart.
Finally, it will run `terraform init` to initialize the Terraform providers (Helm) used to install charts

### just install
This command will inject the `license id` created earlier into the `n8n` values so that the Replicated SDK installation will be successful.
It will then run `terraform apply` to install all the charts specified in the Terraform code.

### just destroy
This command will delete all installed charts as well as delete the test customer.

## Evaluation

**What Worked Well:**

* **Consistency/Reproducibility:** Strongest point via Dagger + Terraform.
* **Simple Interface:** `just` provides a low-friction CLI.
* **Automation:** Reduces repetitive commands.
* **Separation of Concerns:** Clear roles for Terraform, Dagger, `just`.
* **Pipeline as Code:** Version-controlled dev/test/deploy logic via Dagger.

**Friction Points:**

* **Learning Curve:** Terraform and Dagger concepts require learning investment.
* **Initial Setup:** Installation effort for tools.
* **Dagger Complexity:** Can become complex for intricate pipelines; debugging challenges.
* **Cold Starts:** Initial runs take longer (image pulls, provisioning).
* **Terraform `helm_release` Template Change Detection:** Terraform's `helm_release` may not detect *template-only* changes in local charts without a version bump or value change, potentially requiring manual intervention or preferring the Dagger/`helm upgrade` approach for rapid template iteration.
* **State Management:** Handling `kubeconfig` between Terraform/Dagger; Helm state lives outside Terraform unless `helm_release` is used.

**Not Yet Implemented/Tested (Examples):**

* Complex CI/CD integration details.
* Handling inter-chart dependencies locally.
* Advanced validation suites.
* Secure secret management locally.

## Suitability

**This approach is well-suited for:**

* Teams already comfortable with IaC (Terraform) and containerization (Docker).
* Projects where consistency between local development and CI/CD is highly valued.
* Developing complex Helm charts where robust linting, testing, and validation are crucial.
* Teams looking to standardize development workflows across multiple developers or projects.
* Situations where developers need isolated, ephemeral Kubernetes environments frequently.
* Teams wanting to bundle Kubernetes cluster creation and application (Helm chart) installation into a single, automated setup process. This workflow supports this directly using Terraform (managing both cluster resources and `helm_release` resources) or via orchestration through `justfile` (e.g., `just setup` runs Terraform for the cluster, followed by `just deploy` running Dagger for the chart).
* **Is particularly effective for iterating on Helm chart configurations (`values.yaml`)** due to the ease of creating clean environments and reliably testing different value sets.

**It might be overkill for:**

* Very simple Helm charts with minimal testing needs.
* Teams unfamiliar or unwilling to adopt Terraform and/or Dagger.
* Projects where developers prefer direct, manual `helm` and `kubectl` interaction without abstraction layers.
