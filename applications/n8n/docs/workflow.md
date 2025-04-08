# Goal
This document explains how to develop Helm charts with a focus on quick feedback and easy testing. It serves as input for AI agents to create implementation plans.

# For Engineers
This guide focuses on tools and patterns, assuming basic engineering knowledge.

# Project Scope
First, decide if you're creating a new Helm chart or combining existing ones. This guide uses the [n8n](https://github.com/8gears/n8n-helm-chart) chart because:
- It handles workflow automation
- It includes AI components
- It needs a database (CloudNativePG) and Ingress (Nginx)

# Development Plan

## Step 1: Learn the Chart and Dependencies

Each step builds on quick feedback and testing.

Start by learning the application and its Helm chart values:

- n8n: A Node.js workflow automation tool that connects services using a node-based approach
- `values.yaml`: Review the [chart values](https://github.com/8gears/n8n-helm-chart/blob/main/charts/n8n/values.yaml)

Use `helm template` to see what Kubernetes will deploy:

```bash
helm template my-n8n oci://8gears.container-registry.com/library/n8n --version 1.0.0 | ag "# Source"
Pulled: 8gears.container-registry.com/library/n8n:1.0.0
Digest: sha256:318c4abf101e6aa50a5ffad3199f7073eb3a91678f03d37cc358946984150315
# Source: n8n/templates/serviceaccount.yaml
# Source: n8n/templates/service.yaml
# Source: n8n/templates/deployment.yaml
# Source: n8n/templates/tests/test-connection.yaml
```

Study the Helm chart source code for deeper understanding.

At this point, you'll see that n8n needs Nginx Ingress and Postgres. The next step is to automate these dependencies using `helmfile`.