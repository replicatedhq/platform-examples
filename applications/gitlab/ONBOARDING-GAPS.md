# GitLab Onboarding Gaps & Friction Log

This document captures gaps, friction points, and unclear instructions
encountered while running the `replicated-onboarding` plugin on the GitLab
Helm chart example. This feeds Phase 2 improvements to the plugin.

---

## Gap 1: `helm` not installed in polecat environment

**Skill**: `assess-repo`, `install-sdk`
**Severity**: Blocker (self-resolved)
**Description**: The `helm` binary was not in `PATH` on the polecat worker.
The `assess-repo` skill calls `helm lint` and `install-sdk` calls
`helm dependency update`, both of which failed with `command not found: helm`.
**Resolution**: Installed via `brew install helm`. Took ~60s.
**Recommendation**: The skill should detect missing `helm` and provide a
one-line install command rather than failing silently. Or the polecat
environment should have `helm` pre-installed.

---

## Gap 2: `replicated whoami` command does not exist

**Skill**: `create-release` (auth step references `@skills/shared/auth.md`)
**Severity**: Minor friction
**Description**: The skill doc references `replicated whoami` for auth
verification, but `replicated` CLI v0.124.3 does not have a `whoami` command.
The available command is `replicated login` or checking `replicated app ls`.
**Resolution**: Used `replicated app ls` as an auth check.
**Recommendation**: Update `@skills/shared/auth.md` to use `replicated app ls`
or add a note about the CLI version difference.

---

## Gap 3: Replicated API token not clearly documented for automation

**Skill**: `create-release`
**Severity**: Blocker (required Mayor escalation)
**Description**: The task description said "auth via REPL_GITLAB_SA_TOKEN" but
the `create-release` skill only references `@skills/shared/auth.md` which
talks about a `REPLICATED_API_TOKEN` env var. The polecat did not know that
`REPL_GITLAB_SA_TOKEN` was the Replicated API token — it looked like a GitLab
token. Required escalation to Mayor to clarify.
**Resolution**: `REPLICATED_API_TOKEN=$REPL_GITLAB_SA_TOKEN` prefix on commands.
**Recommendation**: Task descriptions for onboarding should explicitly state
which env var maps to `REPLICATED_API_TOKEN`. Or the skill should list which
env vars it checks (e.g., `REPLICATED_API_TOKEN`, `REPL_*_SA_TOKEN`).

---

## Gap 4: `replicated release promote` requires `--app` flag (not positional)

**Skill**: `create-release`
**Severity**: Minor friction
**Description**: The skill doc shows:
```bash
replicated release promote <sequence> <app_slug>/Unstable --version <version>
```
But the actual CLI syntax is:
```bash
replicated release promote <sequence> Unstable --app <app_slug> --version <version>
```
The `<app_slug>/Unstable` format is not valid for this CLI version.
**Resolution**: Used `--app gitlab-pika` flag separately.
**Recommendation**: Update the skill doc to use the `--app` flag form, or
document both syntaxes.

---

## Gap 5: CMX validation blocked — no credits on service account

**Skill**: `validate-cmx`
**Severity**: Blocker (not self-resolvable)
**Description**: Every `replicated cluster create` attempt — from `r1.small`
to `r1.2xlarge` — failed with:
```
Error: Request exceeds available credits. Contact Replicated to buy more credits.
```
The REPL_GITLAB_SA_TOKEN service account has zero CMX credits.
**Resolution**: Skipped CMX validation entirely per Mayor instruction.
**CMX validation will need to run after credits are added to the account.**
**Recommendation**: The `validate-cmx` skill has no guidance for the
"zero credits" failure mode. It should detect this specific error message
and instruct the agent to:
1. Skip CMX validation
2. Document the gap in ONBOARDING-GAPS.md
3. Continue with the rest of the onboarding checklist
Currently, an agent would retry all instance sizes (wasting time) before
escalating. The skill should short-circuit on this error.

---

## Gap 6: GitLab chart resource requirements far exceed other examples

**Skill**: n/a (architecture gap)
**Severity**: Informational
**Description**: GitLab's minimum eval cluster (12 GB RAM, 4 vCPU) is
significantly larger than other examples in this repo (gitea, n8n). The CMX
`r1.medium` instance type is insufficient; `r1.large` or `r1.xlarge` is needed.
**Recommendation**: Document minimum cluster requirements prominently in
README. Consider adding a `ci-values.yaml` that uses heavily reduced resource
requests for lint/template CI checks (which don't actually install the chart).

---

## Gap 7: `validate-cmx` skill uses `--version latest` which is invalid for k3s

**Skill**: `validate-cmx`
**Severity**: Minor friction
**Description**: The skill doc's example uses `--version latest` in the
`replicated cluster create` command. But `k3s` does not support `latest` as
a version string — it requires a specific version like `1.32`.
**Resolution**: Used `--version 1.32` explicitly.
**Recommendation**: Update skill example to use a specific version, or use
`replicated cluster versions` output to select the latest available.

---

## Gap 8: HelmChart `optionalValues` pattern not validated during onboarding

**Skill**: n/a (plugin scope gap)
**Severity**: Informational
**Description**: The `configure-values` and `install-sdk` skills don't
validate that the generated `HelmChart` kind's `optionalValues` are
syntactically correct KOTS YAML. Errors only surface at deploy time.
**Recommendation**: Add a linting step to `create-release` or a new
`validate-kots-manifests` skill that runs `kots` CLI or schema validation
against the generated manifests.

---

## Summary

| # | Gap | Severity | Skill |
|---|-----|----------|-------|
| 1 | `helm` not in PATH | Blocker (self-resolved) | assess-repo, install-sdk |
| 2 | `replicated whoami` doesn't exist | Minor | create-release (auth) |
| 3 | API token identity unclear | Blocker (escalated) | create-release |
| 4 | `release promote` flag syntax wrong | Minor | create-release |
| 5 | CMX: zero credits, no skip guidance | **Blocker (pending)** | validate-cmx |
| 6 | GitLab resource requirements undocumented | Info | n/a |
| 7 | `--version latest` invalid for k3s | Minor | validate-cmx |
| 8 | KOTS manifests not linted | Info | n/a |
