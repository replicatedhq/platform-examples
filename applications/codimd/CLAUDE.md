# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Build Commands

- `task template`: Template the Helm chart
- `task prepare-release`: Prepare files for release
- `task package`: Package the Helm chart
- `task create-release`: Create a new release in Replicated
- `task deploy-helm`: Deploy Helm chart to a cluster

### Lint Commands

- `task lint`: Lint the Helm chart

### Test Commands


- `task validate-helm`: Validate Helm chart (includes linting)
- `task test`: Run Helm tests
- `task debug`: Debug chart template rendering

### Cleanup Commands

- `task clean`: Cleanup the Helm chart
- `task delete-cluster`: Delete the cluster
- `task uninstall`: Uninstall the Helm chart


## Guidelines

### Code Style

- Follow Kubernetes YAML best practices for manifest files
- Use Replicated template functions for dynamic values
- Use consistent indentation (2 spaces) in YAML files
- Always include resource limits and requests in Kubernetes resources
- Prefer declarative configuration over imperative commands

### Helm Charts

- First-party Helm chart templates should be located in the `charts/codimd/templates` directory
- First-party Helm chart values should be located in the `charts/codimd/values.yaml` file
- Helm chart dependencies will be located in the `charts/codimd/charts` directory and will be managed by `helm dependency update`.  Do not author new files in the `charts/codimd/charts` directory.
- Helm chart dependencies should be pinned to specific versions in the `charts/codimd/Chart.yaml` file
- Helm values should be specified in a more-specific key than `global` - in our implementation the `global` key should generally be left empty.

### Replicated Resources

- Replicated resources should be located in the `charts/codimd/replicated` directory.
- The Replicated HelmChart kind should be treated as a consumer of the Helm chart from the `charts/codimd` directory.
- The Replicated HelmChart kind describes the values that are passed into the Helm chart during a Replicated deployment.
- The Replicated HelmChart kind should not be used to author new Helm charts.

### Error Handling

- Include proper linting rules for deployments and pods
- Implement health checks for all deployments
- Add appropriate lifecycle hooks for graceful startup/shutdown

### Documentation

- Add comments to a README.md file to explain the implementation of the release
- Add comments to a TODOS.md file to the root of the application to track any outstanding issues
- Add comments to the CLAUDE.md file to track any specific instructions for Claude
