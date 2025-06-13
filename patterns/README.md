# Patterns

## Table of Contents

Welcome to the repository! Below is a list of available documents and workflows in this project.

### GitHub Workflows

- [Lint and Test Workflow](github-workflows/lint-test.yaml)
- [Release Workflow](github-workflows/release.yml)
- [Compatibility Testing Workflow](github-workflows/compatibility-testing-example.yaml)

#### How to setup Compatibility Testing in GitHub Actions

This tutorial will guide you through setting up compatibility testing in GitHub Actions for your application. It will use the Replicated Compatibility Matrix to test your application against different versions of Kubernetes and different operating systems.

Replicated Compatibility Matrix quickly provisions ephemeral clusters of different Kubernetes distributions and versions, such as OpenShift, EKS, and Replicated kURL.

Before you begin, you will need to have the following:
- credits in your Replicated account to run the Compatibility Matrix cluster
- a GitHub repository with your helm chart code

Here is the step-by-step guide to setting up compatibility testing in GitHub Actions:

1. Create a new GitHub Actions workflow file in your repository. You can do this by creating a new file in the `.github/workflows` directory of your repository. For example, you can create a file named `compatibility-testing.yaml` in the `.github/workflows` directory.
2. In the current workflows, you have two options to run the compatibility testing:
    - Copy [Compatibility Testing Workflow](github-workflows/compatibility-testing-example.yaml) and run the compatibility testing with simple configurations.
3. setup github actions secrets
    - `REPLICATED_API_TOKEN` - [API token](https://docs.replicated.com/reference/replicated-cli-installing#replicated_api_token) for your Replicated Vendor account
    - `REPLICATED_APP` - [Application slug](https://docs.replicated.com/reference/replicated-cli-installing#replicated_app) for your Replicated application
4. customize the `Run Compatibility Testing` step 
```
      - name: Run Compatibility Testing
        run: |
          script to check /healthz 
          or helm deployment status
```

By trigger the github actions, you can integrate the compatibility testing into your CI/CD pipeline.


### Embedded vs External Database

- [Embedded vs External Database](embedded-vs-external-database/README.md)

### Pass Labels and Annotations from Config

- [Pass Labels and Annotations from Config](pass-labels-annotations-from-config/README.md)

### Self-Signed vs User-Provided TLS

- [Self-Signed vs User-Provided TLS](self-signed-vs-user-provided-tls/README.md)

### Wait for Database

- [Wait for Database](wait-for-database/README.md)

### Advanced Options

- [Advanced Options](advanced-options/README.md)

### Multiple Chart Orchestration

- [Multiple Chart Orchestration](multi-chart-orchestration/README.md)

### Validating Images Signatures in a Preflight Check

- [Validating Images Signatures in a Preflight Check](images-signature-preflight/README.md)
