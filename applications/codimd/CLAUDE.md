# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Build Commands

- `task prepare-release`: Prepare files for release
- `task package`: Package the Helm chart
- `task create-release`: Create a new release in Replicated
- `task deploy-helm`: Deploy Helm chart to a cluster

### Lint Commands

- `task lint`: Lint the Helm chart
- `task validate`: Validate Helm chart (includes linting)

### Test Commands

- `task test`: Run Helm tests
- `task debug`: Debug chart template rendering

## Guidelines

### Code Style

- Follow Kubernetes YAML best practices for manifest files
- Use Replicated template functions for dynamic values
- Use consistent indentation (2 spaces) in YAML files
- Always include resource limits and requests in Kubernetes resources
- Prefer declarative configuration over imperative commands

### Error Handling

- Include proper linting rules for deployments and pods
- Implement health checks for all deployments
- Add appropriate lifecycle hooks for graceful startup/shutdown

### Documentation

- Add comments to a README.md file to explain the implementation of the release
