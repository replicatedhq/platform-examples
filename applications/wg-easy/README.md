# WG-Easy Helm Chart Development Pattern

This repository demonstrates a structured approach to developing and deploying Helm charts with Replicated integration. It focuses on a progressive development workflow that builds complexity incrementally, allowing developers to get fast feedback at each stage.

## Core Principles

The WG-Easy Helm Chart pattern is built on five fundamental principles:

### 1. Progressive Complexity

Start simple with individual chart validation and progressively move to more complex environments. This allows issues to be caught early when they are easier to fix.

- Begin with local chart validation
- Move to single chart deployments
- Progress to multi-chart integration
- Finally test in production-like environments

### 2. Fast Feedback Loops

Get immediate feedback at each development stage by automating testing and validation. This shortens the overall development cycle.

- Automated chart validation
- Quick cluster creation and deployment
- Standardized testing at each stage
- Fast iteration between changes

### 3. Reproducible Steps

Ensure consistent environments and processes across all stages of development, eliminating "works on my machine" issues.

- Consistent chart configurations
- Automated environment setup
- Deterministic dependency management
- Standardized deployment procedures

### 4. Modular Configuration

Allow different components to own their configuration independently, which can be merged at release time.

- Per-chart configuration files
- Automatic configuration merging
- Clear ownership boundaries
- Simplified collaborative development

### 5. Automation First

Use tools to automate repetitive tasks, reducing human error and increasing development velocity.

- Task-based workflow automation
- Helmfile for orchestration
- Container-based task running for consistency
- Automated validation and testing
- Streamlined release process

## Repository Structure

```
applications/wg-easy/
├── charts/templates/           # Common templates shared across charts
├── cert-manager/               # Wrapped cert-manager chart
├── cert-manager-issuers/       # Chart for cert-manager issuers
├── replicated/                 # Root Replicated configuration
├── replicated-sdk/             # Replicated SDK chart
├── taskfiles/                  # Task utility functions
├── traefik/                    # Wrapped Traefik chart
├── wg-easy/                    # Main application chart
├── helmfile.yaml               # Defines chart installation order
└── Taskfile.yaml               # Main task definitions
```

## Architecture Overview

![Architecture Diagram](docs/architecture.png)

Key components:
- **Taskfile**: Orchestrates the workflow with automated tasks
- **Helmfile**: Manages chart dependencies and installation order
- **Wrapped Charts**: Encapsulate upstream charts for consistency
- **Shared Templates**: Provide reusable components across charts
- **Replicated Integration**: Enables enterprise distribution

## Learn More

- [Chart Structure Guide](docs/chart-structure.md)
- [Development Workflow](docs/development-workflow.md)
- [Task Reference](docs/task-reference.md)
- [Replicated Integration](docs/replicated-integration.md)
- [Example Patterns](docs/examples.md)

---

This pattern is designed to be adaptable to different applications and requirements. Feel free to modify it to suit your specific needs.