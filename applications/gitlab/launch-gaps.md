# GitLab Launch Gaps

Gaps and friction discovered during the first end-to-end launch of this example.
Used to improve the agent instructions that built this application.

---

## GAP-001: Quickstart missing cluster provisioning step

**What happened:** Running `helm install` failed immediately with "cluster unreachable" because the quickstart assumed a cluster already existed. No step covered creating one.

**Fix applied:** Added step 5 to the README quickstart with the full `replicated cluster create` command and `replicated cluster kubeconfig` to update kubeconfig. Added `make cluster-create` / `make cluster-delete` targets.

**Agent instruction gap:** The agent should include a cluster provisioning step whenever a CMX-based install flow is documented. The quickstart must be runnable end-to-end from a clean state.

---

## GAP-002: Quickstart hid CLI commands behind `make` targets

**What happened:** Initial quickstart steps for install and cluster creation only showed `make install` and `make cluster-create`, giving users no visibility into the underlying `replicated` and `helm` commands.

**Fix applied:** Rewrote steps to show the full CLI commands first, with `make` mentioned as a shortcut alongside them.

**Agent instruction gap:** Quickstart steps should always show the underlying CLI commands explicitly. `make` targets are for convenience, not as the primary instruction. The README is documentation first.

---

## GAP-003: External PostgreSQL and Redis not provisioned before GitLab install

**What happened:** `helm install gitlab` failed with "Progress deadline exceeded" on every workload deployment. Root cause: `cmx-deploy-values.yaml` requires `external-postgresql` and `external-redis` Kubernetes services to exist before install, but no step in the quickstart covered deploying them. The prerequisites were documented only in a comment block inside `cmx-deploy-values.yaml`, not surfaced in the README.

**Fix applied:** Added step 6 to the README with full `helm install bitnami/postgresql` and `helm install bitnami/redis` commands (using `fullnameOverride` to match the expected service names), plus `kubectl create secret` commands. Added `make setup-deps` / `make teardown-deps` targets.

**Agent instruction gap:** When a values file has required prerequisites (external services, secrets), those must be explicit steps in the quickstart — not just comments in the values file. The agent should surface any `# Required:` / `# Prerequisites:` comments from values files as numbered steps in the README.

---

## GAP-004: Bitnami PostgreSQL user lacks superuser — GitLab migrations fail

**What happened:** `helm install gitlab` failed on the migrations job (`gitlab-migrations` Job, status: Failed). GitLab's migration runner executes `CREATE EXTENSION` for `pg_trgm`, `btree_gist`, and `amcheck`, which requires PostgreSQL superuser privileges. The Bitnami PostgreSQL chart creates the application user (`gitlab`) as a non-superuser by default, so migrations abort immediately.

**Fix applied:** Added a `kubectl exec` step to `setup-deps` (and the README) that runs `ALTER USER gitlab SUPERUSER` against the postgres superuser after the chart deploys. The postgres superuser password is read from the chart-generated secret `external-postgresql`.

**Agent instruction gap:** When deploying PostgreSQL via the Bitnami chart for GitLab specifically, the application DB user must be granted superuser. This is a non-obvious GitLab requirement (documented in GitLab's own installation guide but not surfaced in chart values or error messages). The agent should know to include this step whenever setting up GitLab with an external Bitnami PostgreSQL instance.

---

## GAP-005: Bitnami Redis service name always includes `-master` suffix

**What happened:** KAS (and likely sidekiq/webservice) crashed with `redis client: dial tcp: lookup external-redis on ...: no such host`. The `cmx-deploy-values.yaml` had `redis.host: external-redis`, but the Bitnami Redis chart always names its primary service `<fullnameOverride>-master` (i.e., `external-redis-master`), even in standalone mode.

**Fix applied:** Updated `cmx-deploy-values.yaml` `redis.host` from `external-redis` to `external-redis-master`. Added a comment explaining the naming behavior.

**Agent instruction gap:** When using the Bitnami Redis chart, the service name for the master is always `<release-name>-master` or `<fullnameOverride>-master` — never just the base name. Any values file referencing a Bitnami Redis host must use the `-master` suffix.

---

## GAP-006: Bitnami PostgreSQL OOMKilled during GitLab schema load

**What happened:** The migrations job crashed PostgreSQL mid-schema-load with exit code 137 (OOMKilled). GitLab's `structure.sql` is ~32k lines and is loaded in a single transaction, which requires significant PostgreSQL working memory. The Bitnami chart's default `resourcesPreset` allocates too little memory for this workload.

**Fix applied:** Added `--set primary.resourcesPreset=none --set primary.resources.requests.memory=1Gi --set primary.resources.limits.memory=2Gi` to the PostgreSQL install in both the Makefile and README.

**Agent instruction gap:** The Bitnami PostgreSQL chart default resource preset is insufficient for GitLab. When documenting a GitLab + Bitnami PostgreSQL setup, always set explicit memory limits of at least 1Gi request / 2Gi limit on the primary.
