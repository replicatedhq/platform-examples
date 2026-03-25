# Automated Upstream Chart Watching with GitHub Actions

When your Replicated application depends on a third-party Helm chart, keeping it current requires someone to notice new releases, clone the chart, rebuild the package, update the KOTS manifests, lint everything, and open a PR -- tedious work that is easy to forget.

This pattern automates the process with a GitHub Actions workflow that runs daily, detects new chart versions, builds and validates the update, creates a Replicated release, and opens a PR for review.

Source Application: [Akkoma](https://github.com/replicatedhq/platform-examples/blob/main/applications/akkoma)

## How It Works

The workflow runs as a three-job pipeline:

```
check-update ──(if new version)──> build-and-release ──> open-pr
```

1. **check-update** compares the current chart version in your KOTS manifest against the latest release in the upstream chart repo
2. **build-and-release** clones the chart at the new tag, packages it, lints it, and creates a Replicated release on an unstable channel
3. **open-pr** commits the version bump and opens a pull request for human review

If no update is needed, the workflow exits after the first job.

## The Workflow

This is the full workflow. Each section is explained below.

```yaml
name: chart-update

on:
  schedule:
    - cron: '0 8 * * *' # Daily at 8am UTC
  workflow_dispatch:
    inputs:
      chart_version:
        description: 'Force a specific chart version (tag name). If empty, uses latest release.'
        required: false
        default: ''

concurrency:
  group: chart-update
  cancel-in-progress: true

env:
  APP_DIR: applications/my-app
  REPLICATED_API_TOKEN: ${{ secrets.REPLICATED_API_TOKEN }}
  REPLICATED_APP: ${{ vars.REPLICATED_APP || 'my-app' }}
  UPSTREAM_REPO: org/chart-repo
  CHART_PATH: charts/my-chart

jobs:
  check-update:
    runs-on: ubuntu-22.04
    outputs:
      needs_update: ${{ steps.compare.outputs.needs_update }}
      new_version: ${{ steps.compare.outputs.new_version }}
      tag: ${{ steps.upstream.outputs.tag }}
    steps:
      - uses: actions/checkout@v4

      - name: Get latest upstream release
        id: upstream
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          if [ -n "${{ inputs.chart_version }}" ]; then
            tag="${{ inputs.chart_version }}"
          else
            response=$(gh api repos/${{ env.UPSTREAM_REPO }}/releases/latest 2>&1) || {
              echo "ERROR: Failed to fetch latest release from ${{ env.UPSTREAM_REPO }}"
              echo "Response: ${response}"
              exit 1
            }
            tag=$(echo "${response}" | jq -r '.tag_name')
            if [ -z "${tag}" ] || [ "${tag}" = "null" ]; then
              echo "ERROR: No tag_name found in release response"
              exit 1
            fi
          fi
          # Extract semver: strip common chart tag prefixes
          version="${tag#chart-}"
          version="${version#v}"
          echo "tag=${tag}" >> "$GITHUB_OUTPUT"
          echo "version=${version}" >> "$GITHUB_OUTPUT"
          echo "Upstream tag: ${tag}, version: ${version}"

      - name: Compare versions
        id: compare
        run: |
          current=$(grep 'chartVersion:' ${{ env.APP_DIR }}/kots/my-chart.yaml \
            | awk '{print $2}')
          new_version="${{ steps.upstream.outputs.version }}"
          echo "Current: ${current}"
          echo "Upstream: ${new_version}"

          if [ "${current}" = "${new_version}" ]; then
            echo "needs_update=false" >> "$GITHUB_OUTPUT"
            echo "Versions match - nothing to do."
          else
            echo "needs_update=true" >> "$GITHUB_OUTPUT"
            echo "new_version=${new_version}" >> "$GITHUB_OUTPUT"
            echo "Update available: ${current} -> ${new_version}"
          fi

  build-and-release:
    needs: check-update
    if: needs.check-update.outputs.needs_update == 'true'
    runs-on: ubuntu-22.04
    defaults:
      run:
        working-directory: ${{ env.APP_DIR }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Helm
        uses: azure/setup-helm@v4

      - name: Clone upstream chart
        run: |
          tag="${{ needs.check-update.outputs.tag }}"
          git clone --branch "${tag}" --depth 1 \
            https://github.com/${{ env.UPSTREAM_REPO }}.git charts/upstream

      - name: Build chart package
        run: |
          helm dependency update charts/upstream/${{ env.CHART_PATH }}
          helm package charts/upstream/${{ env.CHART_PATH }} -d kots/

      - name: Update chartVersion in HelmChart manifest
        run: |
          version="${{ needs.check-update.outputs.new_version }}"
          yq -i '.spec.chart.chartVersion = "'"${version}"'"' kots/my-chart.yaml

      - name: Lint Helm chart
        run: |
          helm lint charts/upstream/${{ env.CHART_PATH }}

      - name: Lint KOTS manifests
        run: |
          replicated release lint --yaml-dir kots/

      - name: Create Replicated release
        run: |
          version="${{ needs.check-update.outputs.new_version }}"
          replicated release create \
            --yaml-dir kots/ \
            --promote Unstable \
            --version "${version}"

      - name: Clean up chart tarball
        if: always()
        run: |
          rm -f kots/*.tgz

  open-pr:
    needs:
      - check-update
      - build-and-release
    runs-on: ubuntu-22.04
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - name: Install yq
        run: |
          sudo wget -q https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64 \
            -O /usr/local/bin/yq
          sudo chmod +x /usr/local/bin/yq

      - name: Create PR
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          version="${{ needs.check-update.outputs.new_version }}"
          branch="my-app/chart-update-${version}"

          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

          git checkout -b "${branch}"

          yq -i '.spec.chart.chartVersion = "'"${version}"'"' \
            ${{ env.APP_DIR }}/kots/my-chart.yaml

          git add ${{ env.APP_DIR }}/kots/my-chart.yaml
          git commit -m "chore(my-app): update chart to ${version}"
          git push origin "${branch}"

          gh pr create \
            --title "chore(my-app): update chart to ${version}" \
            --body "## Summary
          - Updates Helm chart to version ${version}
          - Chart was built, linted, and released to the Unstable channel

          ## Automated
          This PR was created by the chart-update workflow." \
            --base main \
            --head "${branch}"
```

## Key Design Decisions

### Three jobs instead of one

Three jobs provide clean separation of concerns and conditional execution. The `build-and-release` and `open-pr` jobs run only when `check-update` detects a version change. This saves CI minutes and makes failures easier to diagnose: you see exactly which stage failed.

### Concurrency control

```yaml
concurrency:
  group: chart-update
  cancel-in-progress: true
```

This prevents race conditions when a scheduled run overlaps with a manual dispatch. Only the latest run proceeds; it cancels stale runs.

### Manual override

The `workflow_dispatch` trigger accepts an optional `chart_version` input, letting you force an update to a specific version. This is useful for:

- Testing the workflow with a known version
- Rolling back to an older chart version
- Skipping a bad release and pinning to a specific tag

### Tag prefix stripping

Upstream chart repos use inconsistent tag formats (`v1.2.3`, `chart-v1.2.3`, `chart-1.2.3`). This extraction step strips all common prefixes:

```bash
version="${tag#chart-}"
version="${version#v}"
```

### Replicated release before PR

The workflow creates a Replicated release on the Unstable channel *before* opening the PR. The release is therefore available for testing immediately, and the PR serves as a record of the update. If the build or lint fails, the workflow creates no PR.

### Shallow clone

```bash
git clone --branch "${tag}" --depth 1
```

Git fetches only the tagged commit -- no history, no other branches. This keeps the clone fast and reduces bandwidth.

## Adapting This Pattern

### Prerequisites

You need:

1. A KOTS `HelmChart` custom resource with a `chartVersion` field to update
2. An upstream chart published as GitHub Releases (or adjust the version detection)
3. A `REPLICATED_API_TOKEN` secret with permissions to create releases
4. A `REPLICATED_APP` variable set to your app slug

### For charts hosted in Helm repositories (not GitHub Releases)

Replace the GitHub API call in `check-update` with a Helm repo query:

```bash
helm repo add upstream https://charts.example.com
helm repo update
latest=$(helm search repo upstream/my-chart --output json \
  | jq -r '.[0].version')
```

And replace the `git clone` in `build-and-release` with:

```bash
helm pull upstream/my-chart --version "${version}" --untar -d charts/
```

### For charts in OCI registries

```bash
latest=$(helm show chart oci://registry.example.com/charts/my-chart \
  | grep '^version:' | awk '{print $2}')
helm pull oci://registry.example.com/charts/my-chart \
  --version "${version}" --untar -d charts/
```

### For monorepos with multiple charts

If the upstream repo contains multiple charts, adjust `CHART_PATH` to point to the right subdirectory and update the clone path accordingly. You may also need to parse the chart's `Chart.yaml` for its version rather than relying on the release tag.

### Customizing the release channel

The example promotes to `Unstable`. You might want different behavior:

- **Unstable** for automated testing (shown here)
- **Beta** after CI passes on the PR branch
- **Stable** after the PR merges

To promote to additional channels after the PR merges, create a separate workflow that, on push to `main`, creates a release on a higher channel.

## Setup Checklist

1. Create the workflow file at `.github/workflows/<app>-chart-update.yaml`
2. Set the `REPLICATED_API_TOKEN` secret in your repository settings
3. Set the `REPLICATED_APP` variable (or hardcode it in the env block)
4. Update the `env` block with your app directory, upstream repo, and chart path
5. Update the `chartVersion` grep target to match your HelmChart manifest filename
6. Verify the upstream repo publishes GitHub Releases with version tags
7. Run the workflow manually with `workflow_dispatch` to verify it works before relying on the schedule

## Limitations

- **GitHub Releases only** by default. Charts hosted in Helm repositories or OCI registries require the adaptations described above.
- **Single chart** per workflow. If your application bundles multiple upstream charts, create one workflow per chart or use a matrix-based approach.
- **No automatic merge.** The PR requires human review -- automated chart updates should not reach production unreviewed.
- **Tag format assumptions.** The prefix stripping covers common conventions but may require adjustment for repos with non-standard tag formats.
