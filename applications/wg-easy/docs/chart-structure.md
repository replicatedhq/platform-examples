# Chart Structure Guide

This document explains the modular chart approach used in the WG-Easy Helm chart pattern. Chart wrapping is foundational to the [composable multi-chart workflow](../README.md): by wrapping each upstream chart in a local chart, each team gains a self-contained directory where they own not just values and templates, but also Replicated configuration, support bundle specs, and preflight checks.

### Directory Structure

```
applications/wg-easy/
├── charts/templates/           # Common templates shared across charts
│   ├── traefik-routes.yaml     # Templates for Traefik IngressRoutes
│   └── traefik-route-tcp.yaml  # Templates for Traefik TCP routes
├── cert-manager/               # Wrapped cert-manager chart
├── cert-manager-issuers/       # Chart for cert-manager issuers
├── replicated/                 # Root Replicated configuration
├── replicated-sdk/             # Replicated SDK chart
├── traefik/                    # Wrapped Traefik chart
├── wg-easy/                    # Main application chart
├── helmfile.yaml.gotmpl               # Defines chart installation order
└── Taskfile.yaml               # Main task definitions
```

## Chart Wrapping Concept

Chart wrapping is a core technique in this pattern where upstream Helm charts are encapsulated in local charts rather than used directly. This provides several key benefits:

### Example:
```yaml
# cert-manager/Chart.yaml
apiVersion: v2
name: cert-manager
version: 1.0.0
dependencies:
  - name: cert-manager
    version: '1.14.5'
    repository: https://charts.jetstack.io
  - name: templates
    version: '*'
    repository: file://../templates
```

### Customization Control

Wrapper charts allow you to extend or modify the upstream chart's behavior:

1. **Custom Templates**: Add your own Kubernetes resources alongside the upstream chart
2. **Value Overrides**: Set defaults appropriate for your environment
3. **Additional Resources**: Include related resources that complement the main chart

### Version Management

Wrapped charts give you precise control over dependency versions:

1. **Version Pinning**: Lock dependencies to specific versions for stability
2. **Upgrade Management**: Test upgrades in isolation before promoting to production
3. **Compatibility Assurance**: Ensure all components work together

## Shared Templates

The pattern uses a shared templates chart (`charts/templates/`) that contains reusable components:

```yaml
# From the wg-easy/values.yaml file showing templates usage
templates:
  traefikRoutes:
    web:
      enabled: true
      entryPoint: web
      rule: "Host(`{{ .Values.wireguard.host }}`)"
      service: wg-easy
      port: 51821
```

This approach provides:

1. **Consistency**: Standard implementations across charts
2. **Maintainability**: Single source of truth for common patterns
3. **Simplicity**: Easy reuse of complex configurations

## Chart Composition

The charts are composed together using Helmfile, which manages dependencies and installation order:

```yaml
# Example from helmfile.yaml.gotmpl
releases:
  - name: cert-manager
    namespace: cert-manager
    chart: ./cert-manager
    createNamespace: true
    wait: true

  - name: cert-manager-issuers
    namespace: cert-manager
    chart: .charts/cert-manager-issuers
    createNamespace: true
    wait: true
    needs:
      - cert-manager/cert-manager
```

This ensures that charts are installed in the correct order with proper dependencies.

## Modular Configuration

Each chart can define its own Replicated artifacts that are merged during release preparation:

```
traefik/
├── values.yaml              # Default chart values
├── templates/
│   └── _supportbundle.tpl   # Traefik-specific support bundle collectors/analyzers
└── replicated/
    ├── config.yaml           # Traefik-specific configuration screen items
    └── helmChart-traefik.yaml  # Installation instructions

wg-easy/
├── values.yaml              # Default chart values
├── templates/
│   ├── _supportbundle.tpl   # WG-Easy-specific support bundle collectors/analyzers
│   └── _preflight.tpl       # WG-Easy-specific preflight checks
└── replicated/
    ├── config.yaml           # WG-Easy-specific configuration screen items
    └── helmChart-wg-easy.yaml  # Installation instructions
```

Each chart carries the full set of Replicated artifacts it needs: configuration screen items (`config.yaml`), a HelmChart CR (`helmChart-*.yaml`), support bundle specs (`_supportbundle.tpl`), and preflight checks (`_preflight.tpl`). During release, `task release-prepare` merges per-chart configs into a single file. Support bundles and preflights are rendered into Kubernetes secrets at deploy time and aggregated automatically by Replicated.

Benefits of this approach:

1. **Team Ownership**: Different teams can own their component's configuration, diagnostics, and preflight checks
2. **Clear Boundaries**: Separation of concerns between components
3. **Simplified Maintenance**: Changes to one component don't affect others
4. **Automatic Merging**: During release, all configs are combined into a single file
