# Tools Selection for Helm Chart Workflow

This document explains the tools selected for our Helm chart development, testing, and release workflow, along with the rationale behind each choice.

## Selected Tools

### 1. Replicated CLI

**Selected:** Yes

**Rationale:** The Replicated CLI is essential for our workflow as it provides direct integration with the Replicated platform. It enables us to create, inspect, and promote releases, which are core requirements for our Helm chart deployment process.

**Alternatives:** There are no direct alternatives for Replicated platform integration.

### 2. Taskfile

**Selected:** Yes

**Rationale:** Taskfile provides a simple, YAML-based task runner that is cross-platform, making it ideal for orchestrating our workflow. It offers features like dependencies between tasks, custom variables, and parallel execution. Its simplicity and readability make it accessible to all team members.

**Alternatives:**
- Make: While powerful, Make has syntax that is less intuitive and has inconsistencies across different operating systems.
- just: While similar to Taskfile, we chose Taskfile for its more extensive documentation and wider adoption.

### 3. Bash Scripts

**Selected:** Yes

**Rationale:** Bash scripts are used for specific automation tasks within our workflow. They provide flexibility for custom logic and seamless integration with command-line tools.

**Alternatives:**
- PowerShell: Less portable across different operating systems.
- Python scripts: Would introduce an additional dependency that may not be necessary for simple automation tasks.

### 4. helmfile

**Selected:** Yes

**Rationale:** helmfile allows us to declaratively configure multiple Helm charts in a single file, making it easier to manage deployments of related charts (wg-easy, cert-manager, traefik, and replicated-sdk). It supports templating and environment-specific configurations, which helps maintain consistency across different environments.

**Alternatives:**
- Plain Helm commands: Would require more manual steps and lack the declarative approach.
- Flux/ArgoCD: Too heavyweight for local development workflows.

### 5. Terraform

**Selected:** No

**Rationale:** While Terraform is an excellent tool for infrastructure provisioning, our current workflow focuses primarily on application deployment using Helm charts rather than infrastructure provisioning. We may incorporate Terraform in the future if our workflow expands to include infrastructure management.

**When it might be used:** If we need to provision cloud resources or manage infrastructure beyond Kubernetes deployments.

## Tools Not Selected

### 1. just

**Why it wasn't chosen:** While 'just' is a modern command runner alternative to Make with a simpler syntax and cross-platform support, we ultimately chose Taskfile over 'just' for several reasons:

1. **Ecosystem maturity:** Taskfile has a larger user base and more extensive documentation at this time.
2. **YAML-based configuration:** Taskfile uses YAML which is already widely used in our Kubernetes and Helm workflows, creating consistency across configuration files.
3. **Feature set:** Taskfile offers task dependencies, includes, and parallel execution in a way that better matches our specific workflow needs.
4. **Team familiarity:** More team members were already familiar with Taskfile's syntax and usage patterns.

'just' remains a strong alternative that could be reconsidered in the future if our requirements change or if it adds features that would significantly benefit our workflow.

### 2. Terraform

**Why it wasn't chosen:** Terraform is a powerful infrastructure-as-code tool, but was not selected for our current Helm chart workflow for several reasons:

1. **Scope mismatch:** Our workflow primarily focuses on application deployment via Helm charts rather than infrastructure provisioning. Terraform's core strength is managing cloud resources and infrastructure, which is beyond our current scope.

2. **Complexity overhead:** Incorporating Terraform would add significant complexity to what is primarily an application deployment workflow. This conflicts with our key principle of "Progressive Complexity."

3. **Deployment targets:** Our Helm charts are designed to be deployed to existing Kubernetes clusters, which don't require Terraform for management in our current workflow.

4. **Learning curve:** Terraform has a steeper learning curve compared to the other tools in our stack, and would require additional team training for minimal immediate benefit.

5. **State management:** Terraform's state management adds operational complexity that's unnecessary for our current deployment needs.

Terraform would become valuable if we expand our workflow to include:
- Provisioning Kubernetes clusters on cloud providers
- Managing related infrastructure (databases, storage, networking)
- Creating complete environments from scratch
- Implementing multi-cloud deployment strategies

We may incorporate Terraform in a future iteration as our infrastructure needs become more complex.

## Conclusion

Our tool selection emphasizes simplicity, cross-platform compatibility, and automation to enable a reproducible workflow for Helm chart development, testing, and releases. The combination of Taskfile for orchestration, Bash for custom logic, helmfile for managing multiple Helm charts, and the Replicated CLI for platform integration provides a balanced approach that minimizes complexity while meeting all our requirements.

The tools were chosen based on the key principles of Progressive Complexity, Fast Feedback, Reproducibility, Modular Configuration, and Automation as outlined in our design document. 
