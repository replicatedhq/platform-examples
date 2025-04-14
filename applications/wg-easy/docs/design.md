# Helm Chart Design

## Objective

Provide a design for the Helm chart with a clear, reproducible workflow for iterative Helm chart development, testing, and promoting releases. The workflow leverages the Replicated CLI to create a release, inspect the release, and promote the release to a channel.

## Available Tools

- [Replicated CLI](https://help.replicated.com/docs/reference/cli/replicated/)
- [Taskfile](https://taskfile.dev/)
- [Terraform](https://www.terraform.io/)
- [just](https://github.com/casey/just)
- Bash
- [helmfile](https://github.com/helmfile/helmfile)

## Helm Chart Components

- **wg-easy**: The Helm chart for the wg-easy application. The Helm chart is located `applications/wg-easy/wg-easy`
- **cert-manager**: The Helm chart for the cert-manager application. The Helm chart is located `applications/cert-manager/cert-manager`
- **traefik**: The Helm chart for the traefik application. The Helm chart is located `applications/traefik/traefik`
- **replicated-sdk**: The Helm chart for the replicated-sdk application. The Helm chart is located `applications/replicated-sdk/replicated-sdk`

## Key Principles

- **Progressive Complexity** – Start simple, add complexity incrementally.
- **Fast Feedback** – Immediate validation of changes.
- **Reproducibility** – Simple to recreate locally.
- **Modular Configuration** – Clear separation of values per component.
- **Automation** – Minimize repetitive tasks.

## Design Steps

1. Review the existing Helm chart and the Replicated CLI commands.
2. Choose Best Tools based on the complexity of the Helm chart and the Replicated CLI commands.
3. Explain why we choose the tools we do and compare them to other tools. Save the decision document to `docs/memory_bank/` folder with the file name `tools_choose.md`. In the document, we should include the following information:
   - Why we choose the tools we do
   - Compare the chosen tools to other tools
   - What are the alternatives to the chosen tools
   - What are the trade-offs of the chosen tools
   - What are the best practices for using the chosen tools
   - What are the limitations of the chosen tools
