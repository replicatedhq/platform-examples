# WG-Easy: Composable Multi-Chart Workflow for Replicated

This project demonstrates a **composable multi-chart workflow** for packaging and distributing a Kubernetes application with [Replicated](https://www.replicated.com/). Unlike the monolithic single-chart approach used by other apps in this repo (storagebox, gitea, powerdns), wg-easy is structured so that multiple teams can own independent charts and have their configuration, support bundles, and preflight checks assembled automatically at release time.

The target scenario: multiple teams, multiple product verticals, one Replicated release.

## The Problem with Monolithic Releases

In a monolithic Replicated application, all components share a single set of release artifacts:

- One `kots-config.yaml` defines the entire configuration screen. Every team edits it.
- One `kots-support-bundle.yaml` defines all diagnostics. Every team must update it when adding components.
- One HelmChart custom resource installs one chart. All values live in one place.
- Adding a new component means coordinating changes across shared files that every team touches.

This works for small applications owned by a single team. It breaks down when multiple teams contribute components to a single product -- changes collide, ownership boundaries blur, and the cognitive overhead of understanding the full configuration grows with every component added.

## How the Composable Workflow Solves It

The wg-easy project splits the application into independently owned charts, each carrying its own Replicated artifacts. Three mechanisms make this work:

### Per-Chart Ownership

Each chart under `charts/` has its own `replicated/` directory containing the artifacts that team owns:

```
charts/wg-easy/
  replicated/
    config.yaml             # Config screen items for this component
    helmChart-wg-easy.yaml  # HelmChart CR for this component
  templates/
    _supportbundle.tpl      # Support bundle specs for this component
    _preflight.tpl          # Preflight checks for this component
```

Teams work in their chart directory. They don't need to understand or edit other teams' configuration.

### Automatic Assembly

The `task release-prepare` command walks all `charts/*/replicated/` directories, merges per-chart `config.yaml` files into a unified configuration screen, sets chart versions, packages charts, and produces a complete `release/` directory ready for the Replicated Vendor Portal. No manual merging required.

### Helmfile Orchestration

Charts are deployed in dependency order via `helmfile.yaml.gotmpl`. The same helmfile serves two purposes through Helmfile environments:

- **`default` environment**: Charts are installed from local paths (`./charts/cert-manager`, `./charts/wg-easy`, etc.). The Replicated SDK is disabled. This is the inner development loop -- validate chart changes against a test cluster without touching the Replicated platform.

- **`replicated` environment**: Charts are pulled from the Replicated OCI registry (`oci://registry.replicated.com/<app>/<channel>/<chart>`), authenticated with a customer license ID. Container images are routed through the Replicated registry proxy. The Replicated SDK is enabled. This simulates what an end customer's installation looks like.

```bash
# Local development -- charts from disk
task helm-install

# Customer-like installation -- charts from Replicated registry
task helm-install HELM_ENV=replicated
```

This means you can develop locally with fast feedback, then verify the same charts install correctly through the Replicated distribution path -- same helmfile, same dependency ordering, different source and image configuration.

## Composable vs Monolithic

| Aspect | Monolithic (storagebox, gitea) | Composable (wg-easy) |
|--------|-------------------------------|----------------------|
| Config screen | Single `kots-config.yaml` | Per-chart `config.yaml`, merged at release |
| Support bundle | Single `kots-support-bundle.yaml` | Per-chart `_supportbundle.tpl`, deployed as secrets |
| Preflight checks | Single spec in release dir | Per-chart `_preflight.tpl`, auto-aggregated |
| HelmChart CRs | Single file | Per-chart `helmChart-*.yaml` |
| Adding a component | Edit shared files, coordinate with other teams | Add a chart with its own `replicated/` dir |
| Orchestration | Make + single helm install | Helmfile with dependency ordering |

## End-to-End GitHub Actions

The CI/CD pipeline validates every pull request through a complete cycle:

1. **Chart validation** -- linting, template rendering, helmfile syntax
2. **Chart packaging** -- build once, share artifacts between jobs
3. **Release creation** -- create Replicated channel and release from assembled artifacts
4. **Compatibility matrix testing** -- deploy and test across multiple Kubernetes distributions and versions
5. **Cleanup** -- remove test clusters, customers, and channels

See [CI Workflow Documentation](docs/ci-workflow.md) for details.

## Repository Structure

```
applications/wg-easy/
├── charts/
│   ├── cert-manager/            # Wrapped cert-manager chart
│   ├── cert-manager-issuers/    # Chart for cert-manager issuers
│   ├── replicated-sdk/          # Replicated SDK chart
│   ├── templates/               # Common templates shared across charts
│   ├── traefik/                 # Wrapped Traefik chart
│   └── wg-easy/                 # Main application chart
├── replicated/                  # Root Replicated configuration
├── taskfiles/                   # Task utility functions
├── helmfile.yaml.gotmpl         # Defines chart installation order
└── Taskfile.yaml                # Main task definitions
```

## Quick Start

### Prerequisites

Local tools and Helm plugins needed:

```bash
helm, helmfile
go-task
replicatedhq/replicated/cli

helm-diff plugin:
helm plugin install https://github.com/databus23/helm-diff --verify=false
```

### Essential Commands

```bash
# List all available tasks
task --list

# Full test cycle (create cluster, deploy, test, clean up)
task -v full-test-cycle

# Individual development tasks
task cluster-create          # Create test cluster
task dependencies-update     # Download chart dependencies
task -v helm-install         # Deploy charts with detailed output
task test                    # Run validation tests
task cluster-delete          # Clean up resources

# Release preparation
task release-prepare         # Package charts and merge configs
task release-create          # Create and promote release
```

Use `task -v <taskname>` for detailed execution output during development and debugging.

## Architecture Overview

Key components:

- **Taskfile**: Orchestrates the workflow with automated tasks
- **Helmfile**: Manages chart dependencies and installation order
- **Wrapped Charts**: Encapsulate upstream charts with per-chart Replicated artifacts
- **Shared Templates**: Provide reusable components across charts (Traefik routes, image pull secrets)
- **Replicated Integration**: Enables enterprise distribution with modular configuration

## Learn More

- [Composable Multi-Chart Walkthrough](../../patterns/composable-multi-chart-walkthrough/README.md) -- end-to-end guided tour of the data flow from chart structure through release assembly
- [Chart Structure Guide](docs/chart-structure.md) -- chart wrapping, shared templates, modular configuration
- [Development Workflow](docs/development-workflow.md) -- progressive complexity from lint to embedded cluster
- [Task Reference](docs/task-reference.md) -- complete task documentation
- [Replicated Integration](docs/replicated-integration.md) -- per-chart config, support bundles, preflights
- [CI Workflow](docs/ci-workflow.md) -- GitHub Actions pipeline and compatibility matrix
- [Example Patterns](docs/examples.md) -- concrete usage examples
