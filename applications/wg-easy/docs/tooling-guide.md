# Tooling Guide

This project uses several automation tools to streamline development. These tools are **convenient but not required** -- the patterns demonstrated here (composable multi-chart ownership, wrapped charts, helmfile-based orchestration, automatic release assembly) are tool-agnostic. You can reproduce them with Make, shell scripts, CI pipeline steps, or any other workflow tool.

If you are here to learn the patterns, start with the [README](../README.md) or the [Composable Multi-Chart Walkthrough](../../../patterns/composable-multi-chart-walkthrough/README.md). Come back to this page when you want to understand what a specific command is doing under the hood, or when you want to translate the workflows to your own tooling.

## The Tool Stack

### Task (go-task) -- instead of Make

[Task](https://taskfile.dev) is a YAML-based task runner. It provides a single command interface (`task <name>`) for multi-step workflows that would otherwise require remembering several shell commands and their flags.

- **Configuration**: [`Taskfile.yaml`](../Taskfile.yaml) (main definitions) and [`taskfiles/`](../taskfiles/) (shared utilities)
- **See what it runs**: Use `task -v <name>` to print every shell command as it executes

**Why Task instead of Make?** Make would work fine here -- every `task` command could be a Makefile target. We chose Task because it fits more naturally in a project that is already YAML-heavy (Helm charts, Kubernetes manifests, helmfile). Specific advantages over Make for this use case:

- **Variables with defaults and overrides** -- Taskfile variables support defaults, environment variable fallback, and per-invocation overrides (`task cluster-create K8S_VERSION=1.31.2`) without the quoting and override-precedence quirks of Make.
- **Status checks for idempotency** -- Tasks can define `status:` conditions that skip execution when the desired state already exists (e.g., skip cluster creation if the cluster is already running). Make's equivalent is file-based timestamps, which do not map well to remote API state like clusters and releases.
- **Task dependencies with ordering** -- `deps:` and `cmds:` give explicit control over what runs in parallel versus sequentially. Make has prerequisites, but expressing "run A before B, and skip A if its status check passes" requires more boilerplate.
- **Built-in discoverability** -- `task --list` shows every task with its description. `task -v <name>` prints every shell command as it executes, making the Taskfile self-documenting.

None of this is unique to Task. If you are comfortable with Make, the [translation table](#task-to-command-translation) below shows the underlying commands you would put in your Makefile targets.

### Helmfile -- instead of plain Helm CLI

[Helmfile](https://helmfile.readthedocs.io) is a declarative orchestrator for multiple Helm releases. It sits on top of the standard Helm CLI and adds capabilities that matter when you are managing several charts as a single application.

- **Configuration**: [`helmfile.yaml.gotmpl`](../helmfile.yaml.gotmpl)
- **Under the hood**: Runs `helm install` or `helm upgrade` for each release entry, in the order dictated by `needs:`.

**Why Helmfile instead of plain `helm install`?** The Helm CLI installs one chart at a time. That is fine for a single-chart application, but this project deploys five charts (cert-manager, cert-manager-issuers, Traefik, Replicated SDK, wg-easy) that must be installed in a specific order with different configuration depending on the environment. Helmfile handles this declaratively:

- **Dependency ordering** -- the `needs:` field ensures charts install in the right sequence. cert-manager must be running before its issuers can be created; issuers must exist before Traefik can request certificates. With plain Helm you would script this ordering yourself and manage `--wait` flags to block between installs.
- **Environment switching** -- a single `helmfile.yaml.gotmpl` defines two environments. The `default` environment installs charts from local paths (`./charts/cert-manager`) for fast inner-loop development. The `replicated` environment pulls the same charts from the Replicated OCI registry (`oci://registry.replicated.com/...`) with image proxy rewrites, simulating the customer installation experience. Switching between them is a single flag: `helmfile -e replicated sync`. Without Helmfile you would maintain separate values files or write conditional logic to swap chart sources and image references.
- **Dynamic configuration** -- the `.gotmpl` extension means the file is a Go template. It uses `exec "yq"` calls to read chart versions directly from each chart's `Chart.yaml` at deploy time, so you never have to update versions in two places.
- **Atomic multi-chart deploys** -- Helmfile can roll back all releases if any one fails (`atomic: true`, `cleanupOnFail: true`), giving you transactional behavior across the whole application stack.

You do not need Helmfile to use the patterns in this project. But if you replace it, you need to handle install ordering and environment-specific configuration yourself -- see [Bringing Your Own Tools](#bringing-your-own-tools).

### yq

[yq](https://github.com/mikefarah/yq) is a command-line YAML processor (like `jq` for JSON, but for YAML). It is not used as a standalone workflow tool -- it appears inside the `release-prepare` task to:

- Merge per-chart `config.yaml` files into a single release config
- Extract namespaces from `helmChart-*.yaml` files into `application.yaml`
- Set chart versions from each chart's `Chart.yaml`

### Replicated CLI

The [Replicated CLI](https://docs.replicated.com/reference/replicated-cli-overview) manages resources on the Replicated Vendor Portal. It is used inside several tasks for:

- **Cluster management**: `replicated cluster create`, `replicated cluster ls`, `replicated cluster rm`
- **Release publishing**: `replicated release create --yaml-dir ./release --promote <channel>`
- **Customer management**: `replicated customer create`, `replicated customer ls`

### Helm CLI

Standard [Helm](https://helm.sh) is used directly throughout the project for `dependency update`, `lint`, `template`, `package`, `install`, and `uninstall`. Most `task` commands are thin wrappers that loop `helm` over every chart in the `charts/` directory.

## Task-to-Command Translation

Every `task` command maps to standard shell commands. The table below covers the most common operations. For the complete list, see the [Task Reference](task-reference.md) or run `task --list`.

| Task command | What it actually runs | Where to look |
|---|---|---|
| `task dependencies-update` | `helm dependency update` for each chart directory | `Taskfile.yaml` &rarr; `dependencies-update` |
| `task chart-lint-all` | `helm lint` for each chart directory | `Taskfile.yaml` &rarr; `chart-lint-all` |
| `task chart-template-all` | `helm template test-release <chart> --dry-run` for each chart | `Taskfile.yaml` &rarr; `chart-template-all` |
| `task chart-validate` | lint + template + `helmfile build` | `Taskfile.yaml` &rarr; `chart-validate` |
| `task helm-install` | `helmfile sync --wait` (with kubeconfig and env vars) | `Taskfile.yaml` &rarr; `helm-install` |
| `task release-prepare` | `find`/`cp` replicated YAMLs, `yq` merge configs, `helm package` each chart | `Taskfile.yaml` &rarr; `release-prepare` |
| `task release-create` | `replicated release create --yaml-dir ./release --promote <channel>` | `Taskfile.yaml` &rarr; `release-create` |
| `task cluster-create` | `replicated cluster create --name <name> --kubernetes-version <ver> --distribution <dist>` | `Taskfile.yaml` &rarr; `cluster-create` |
| `task full-test-cycle` | Runs in sequence: cluster-create, setup-kubeconfig, ports-expose, dependencies-update, helm-preflight, helm-install, test, cluster-delete | `Taskfile.yaml` &rarr; `full-test-cycle` |

To see the exact commands for any task, run:

```bash
task -v <taskname>
```

## Bringing Your Own Tools

The patterns in this project do not depend on Task or Helmfile. Here is how to translate the workflow to other approaches:

**If you use Make or shell scripts**, the translation table above gives you the underlying commands. Put them in Makefile targets or a `deploy.sh` script. Most tasks are short loops over `find charts/ -name Chart.yaml` that run a Helm command on each result.

**If you use CI pipelines directly** (GitHub Actions, GitLab CI, etc.), each task maps to a pipeline step. The Helm and Replicated CLI commands are what you run directly in your step definitions. This project's own [CI workflow](ci-workflow.md) demonstrates this -- it uses the official [replicated-actions](https://github.com/replicatedhq/replicated-actions) for resource management rather than wrapping Task.

**If you replace Helmfile**, you need to handle two things yourself:

1. **Install ordering** -- Helmfile's `needs:` field ensures cert-manager installs before its issuers, issuers before Traefik, and so on. Without it, you need to sequence your `helm install` calls or use Helm's `--wait` flag with manual ordering.
2. **Environment-specific values** -- Helmfile's `environments:` block switches between local chart paths and OCI registry sources, and toggles image proxy rewrites. Without it, you would manage separate values files or use conditional logic in your deployment scripts.

Everything else -- chart wrapping, per-chart `replicated/` directories, config merging, support bundle and preflight patterns -- works the same regardless of which tools drive the workflow.
