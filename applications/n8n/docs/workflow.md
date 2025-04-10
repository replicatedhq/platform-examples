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

### 1. Local Cluster Setup

-   **Action:** Create a local Kubernetes cluster using k3d.
-   **Command Example:** `k3d cluster create mydevcluster --port 8080:80@loadbalancer --port 8443:443@loadbalancer`
-   **Verification:** Confirm cluster access with `kubectl cluster-info`.

### 2. Initialize Dependencies (Terraform)

-   **Action:** Define `helm_release` resources in `main.tf` for CloudNativePG and Traefik.
-   **Configuration:** Specify chart repositories, versions, and necessary values within the Terraform HCL. Reference external values files if preferred (e.g., `values/traefik-values.yaml`, `values/cnpg-values.yaml`).
-   **Command:** `terraform init && terraform apply`
-   **Verification:** Check for running pods/services for Postgres and Traefik using `kubectl get pods,svc -A`. Ensure Terraform state reflects the deployed releases.

### 3. Create Initial Local Chart (`n8n`)

-   **Action:** Use Helm CLI to scaffold the `n8n` chart.
-   **Command:** `helm create charts/n8n`
-   **Cleanup:** Remove default template files not immediately needed (e.g., `hpa.yaml`, `ingress.yaml`, `serviceaccount.yaml`, test files). Keep `_helpers.tpl`, `deployment.yaml`, `service.yaml`, `NOTES.txt`.
-   **Initial Values:** Review and potentially simplify the initial `charts/n8n/values.yaml`.

### 4. Configure `justfile` for Core Workflow

-   **Action:** Define initial recipes in `justfile`.
-   **Recipes:**
    -   `lint`: Run `helm lint ./charts/n8n -f ./charts/n8n-values.yaml`.
    -   `template`: Run `helm template n8n ./charts/n8n -f ./charts/n8n-values.yaml > rendered-n8n.yaml`.
    -   `deploy`: Run `helm upgrade --install n8n ./charts/n8n -f ./charts/n8n-values.yaml --create-namespace --namespace n8n`.
    -   `delete`: Run `helm uninstall n8n --namespace n8n`.
    -   `logs`: Run `kubectl logs -f -l app.kubernetes.io/name=n8n -n n8n --tail=50`.

### 5. Iterative Development Cycle

-   **Action:** Develop the `n8n` chart incrementally.
    -   **Step 1 (Basic Deployment):**
        -   Modify `charts/n8n/templates/deployment.yaml` for the n8n image and basic configuration.
        -   Modify `charts/n8n/templates/service.yaml` to expose the n8n port.
        -   Update `charts/n8n/values.yaml` and `charts/n8n-values.yaml` with necessary image details, ports, etc.
        -   **Test:** `just lint`, `just template` (review output), `just deploy`, `just logs`, check service (`kubectl get svc -n n8n`).
    -   **Step 2 (Add Database Connection):**
        -   Update `deployment.yaml` to include environment variables for database connection (host, user, password, db name).
        -   Source these values from `values.yaml` (potentially using secrets later).
        -   Reference the Postgres service created by CloudNativePG (check its service name/namespace, usually managed via Terraform outputs or known conventions).
        -   Update `n8n-values.yaml` with actual DB connection details.
        -   **Test:** `just deploy`, `just logs` (check for connection errors), access n8n if possible.
    -   **Step 3 (Add Ingress):**
        -   Add `charts/n8n/templates/ingress.yaml`.
        -   Parameterize hostname, path, TLS settings using `values.yaml`.
        -   Ensure Traefik's IngressClass is correctly referenced (as deployed by Terraform).
        -   Update `n8n-values.yaml` with ingress details.
        -   **Test:** `just deploy`, access n8n via the defined hostname (may require local `/etc/hosts` modification).
    -   **Step 4 (Add Persistence, ConfigMaps, Secrets, etc.):**
        -   Incrementally add other required Kubernetes objects (PVCs, ConfigMaps, Secrets).
        -   Follow the `modify -> lint -> template -> deploy -> test` cycle for each addition.

### 6. Managing Configuration & Secrets

-   **Action:** Refine value management.
-   **Explain:** How `charts/n8n/values.yaml` provides defaults and `charts/n8n-values.yaml` provides overrides for the local development environment.
-   **Introduce Secrets:** Discuss strategies (e.g., manual `kubectl create secret`, Sealed Secrets, External Secrets Operator, Terraform-managed secrets) and integrate one method for sensitive values like database passwords. Update `deployment.yaml` to use `valueFrom: secretKeyRef`.

### 7. Adding Helm Tests

-   **Action:** Create basic Helm tests.
-   **Example:** Add a test pod definition in `charts/n8n/templates/tests/test-connection.yaml` that tries to connect to the n8n service.
-   **Update `justfile`:** Add `test: helm test n8n --namespace n8n`.
-   **Test:** Run `just test` after a successful `just deploy`.

### 8. Integrating Dagger (Packaging/Release - Optional)

-   **Action:** Introduce Dagger for CI/CD related tasks.
-   **Setup:** Create basic Dagger functions in the `dagger/` directory (e.g., using Go or Python SDK).
-   **Example Functions:**
    -   `dagger call package --chart-dir ./charts/n8n --version <version>`: Runs `helm dependency update` and `helm package`.
    -   `dagger call publish --chart-path <packaged-chart.tgz> --repo <oci://...>`: Pushes the chart to an OCI registry.
-   **Update `justfile`:** Add recipes like `just package` and `just publish` that invoke Dagger.

### 9. Cleanup

-   **Action:** Document cleanup steps.
-   **Commands:**
    -   `just delete` (or `helm uninstall n8n -n n8n`)
    -   `terraform destroy` (to remove CloudNativePG, Traefik, and any other Terraform-managed resources)
    -   `k3d cluster delete mydevcluster`
-   **Update `justfile`:** Add a `clean-all` recipe combining relevant uninstall/destroy commands.

### 10. Documentation & Final Touches

-   **Action:** Review and finalize the `docs/` content.
-   **Explain:** How the `justfile` ties everything together for the developer.
-   **Summarize:** Reiterate the workflow benefits (fast feedback, reproducibility).

## Known Friction Points

- Terraform may fail to diff changes to chart, e.g. add new dependency in Chart.yaml

## Suitable Use Cases

This workflow fits best for teams:

- Requiring rapid local iteration
- Using mixed (local/remote) Helm charts
- Familiar with Helm, Terraform, and Kubernetes basics

## Immediate Next Steps for Implementation
