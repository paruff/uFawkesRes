# uFawkesRes — Implementation Plan v0.2
*Lean issues for Deepseek v4 flash implementation*

**Status:** Draft — 2026-06-23
**Branch strategy:** One branch per issue: `feat/RES-001-pre-commit`, etc. PRs to `main`.
**Test gate:** `pytest tests/unit/` + `pre-commit run --all-files` must pass on every PR.
**Definition of done:** All acceptance criteria checked + test gate passing + `yamllint compose.yaml` clean.

---

## ⚠ Mandatory first action — amend all prior plane documents

Before any RES issue is started, the following cross-repo corrections must be made.
These are not Deepseek implementation tasks — they are human corrections to documents
produced earlier in this session that used the wrong network name.

| Document | What to change |
|---|---|
| `specification.md` (uFawkesPipe) | `fawkes-net` → `ufawkes-resources_fawkes-backbone-net`; `postgres:5432` → `fawkes-postgres:5432`; `sonarqube:9000` external reference updated |
| `design.md` (uFawkesPipe) | All compose network blocks corrected |
| `sec-specification.md` | `fawkes-net` → `ufawkes-resources_fawkes-backbone-net`; `postgres:5432` → `fawkes-postgres:5432`; `valkey:6379` → `fawkes-cache:6379` |
| `sec-design.md` | Same corrections; DefectDojo connection strings updated |
| `devx-specification.md` | All connection strings updated |
| `devx-design.md` | `compose.yaml` network block corrected |
| `devx-plan.md` | DX-002 acceptance criteria corrected |
| `fawkes-integration.md` | Network name, all DNS names, port table corrected |

The integration document also needs one new section: **Traefik routing** — how
downstream service labels connect to the Traefik gateway and Authelia middleware.

---

## Prerequisites (human actions before any issue can start)

- [ ] **P1:** Verify current Authelia stable patch tag at https://github.com/authelia/authelia/releases (blocks RES-002)
- [ ] **P2:** Confirm whether `traefik/traefik.yml` and `authelia/configuration.yml` already exist in the repo (blocks RES-002 scope — create vs update)
- [ ] **P3:** Decide on the hostname scheme: `*.localhost` subdomains or a real LAN hostname (e.g. `*.fawkes.local`) (blocks RES-003)
- [ ] **P4:** Decide whether Postgres port 5432 is exposed to host in dev (blocks RES-002)
- [ ] **P5:** Confirm Valkey version — verify at https://hub.docker.com/r/valkey/valkey (blocks RES-002)

---

## RES-001 · Add pre-commit, `.gitleaks.toml`, tests scaffold

**Type:** chore
**Estimated effort:** 30 min
**Depends on:** nothing
**Branch:** `feat/RES-001-tooling`

### Context
The README mentions no pre-commit or test infrastructure. This issue adds the
foundational tooling that every subsequent PR's test gate depends on.

### Acceptance criteria
- [ ] `.pre-commit-config.yaml` created with: `gitleaks` v8.18.2, `detect-secrets`,
  `yamllint`, `markdownlint-cli`, `prettier`
- [ ] `.gitleaks.toml` created (minimal standard config)
- [ ] `.secrets.baseline` generated: `detect-secrets scan > .secrets.baseline`
  (must exclude the placeholder hash in `authelia/users_database.yml`)
- [ ] `.yamllint` created (max line length 120)
- [ ] `.markdownlint.json` created
- [ ] `tests/unit/__init__.py` created (empty)
- [ ] `tests/requirements.txt` created: `pytest`, `pyyaml`
- [ ] `scripts/` directory created with empty `.gitkeep`
- [ ] `pre-commit run --all-files` passes on files created in this issue

### Implementation notes for Deepseek
The `authelia/users_database.yml` placeholder argon2id hash will trigger `detect-secrets`
as a false positive. Add a `# pragma: allowlist secret` comment on the password line,
or add a `.secrets.baseline` exclusion. Do not remove the placeholder — operators
need to see where to put the real hash.

---

## RES-002 · Write or harden `compose.yaml`, Traefik config, and Authelia config

**Type:** feat / infra
**Estimated effort:** 3 hr
**Depends on:** RES-001, P1 (Authelia version), P2 (existing files), P4 (Postgres port), P5 (Valkey version)
**Branch:** `feat/RES-002-compose`

### Context
The existing `compose.yaml` (if it exists — resolve P2 first) uses Traefik and
Authelia. This issue pins all image versions, adds Docker secrets for Authelia,
adds `depends_on` with health conditions, writes the Traefik static config and
dynamic config, and writes the Authelia `configuration.yml` and `users_database.yml`
if they do not already exist. Closes the most critical structural gaps in the repo.

### Acceptance criteria

**`compose.yaml`:**
- [ ] All 4 services present: `traefik`, `fawkes-sso`, `fawkes-postgres`, `fawkes-cache`
- [ ] All images pinned to specific versions (no `:latest`)
- [ ] `traefik` image: `traefik:v3.7.5`; `fawkes-postgres` image: `postgres:17-alpine`;
  `fawkes-cache` image: `valkey/valkey:8.1-alpine`; `fawkes-sso` image: verified Authelia tag
- [ ] `fawkes-sso` has `depends_on` with `condition: service_healthy` for both postgres and cache
- [ ] All 4 services have `healthcheck` blocks matching spec §9 acceptance criteria
- [ ] `fawkes-sso` uses 4 Docker secrets via `file:` references to `./authelia/secrets/`
- [ ] `fawkes-postgres` uses Docker secret for superuser password
- [ ] `fawkes-cache` command includes `--requirepass ${VALKEY_PASSWORD}` and `--appendonly yes`
- [ ] `traefik` mounts `traefik.yml` and `dynamic/` directories read-only
- [ ] Network `fawkes-backbone-net` declared as `driver: bridge` (NOT external)
- [ ] `postgres-data` and `valkey-data` named volumes declared
- [ ] `secrets` top-level block lists all 5 secrets with `file:` paths

**`traefik/traefik.yml`:**
- [ ] Created per design.md §4: `api.insecure: true`, `providers.docker.exposedByDefault: false`,
  `providers.docker.network: fawkes-backbone-net`, `entryPoints.web.address: ":80"`, `ping: {}`
- [ ] `providers.file.directory: /etc/traefik/dynamic` with `watch: true`

**`traefik/dynamic/middlewares.yml`:**
- [ ] Created per design.md §5 (documentation/reference file only)

**`authelia/configuration.yml`:**
- [ ] Created per design.md §6 **if it does not already exist** (P2 resolution)
- [ ] All connection strings use `fawkes-postgres` and `fawkes-cache` as hostnames
- [ ] `session.redis.database_index: 0`
- [ ] `access_control.default_policy: deny`
- [ ] `notifier.filesystem` (no SMTP for local dev)

**`authelia/users_database.yml`:**
- [ ] Created with one `admin` user entry and placeholder argon2id hash
- [ ] Comment above hash explains how to generate a real hash

**`.env.example`:**
- [ ] Updated with `VALKEY_PASSWORD`, `POSTGRES_SUPERUSER`, `CODER_DB_PASSWORD`,
  `BACKSTAGE_DB_PASSWORD`, `DOJO_DB_PASSWORD`, `INFISICAL_DB_PASSWORD`

**Tests:**
- [ ] `tests/unit/test_compose_yaml.py` created per design.md §11
- [ ] `tests/unit/test_traefik_config.py` created per design.md §11
- [ ] `tests/unit/test_authelia_config.py` created per design.md §11
- [ ] `pytest tests/unit/` passes
- [ ] `yamllint compose.yaml traefik/traefik.yml authelia/configuration.yml` passes

### Implementation notes for Deepseek
**Do not invent Authelia configuration field names.** The Authelia v4.38
configuration reference is at https://www.authelia.com/configuration/. Field names
and structure changed significantly between v4.36 and v4.38. Read the docs for the
pinned version before writing `configuration.yml`.

**Do not invent Traefik label syntax.** The ForwardAuth middleware label format for
Traefik v3 + Authelia v4.38 is at https://www.authelia.com/integration/proxies/traefik/.
The endpoint path (`/api/authz/forward-auth`) must be verified against the version used.

The `fawkes-sso` container Traefik labels define the `authelia@docker` middleware that
downstream planes reference. These labels must be exactly correct or no downstream
service will be able to authenticate.

---

## RES-003 · Write `scripts/init.sh` and `scripts/db-create.sh`, extend Makefile

**Type:** feat / ops
**Estimated effort:** 1.5 hr
**Depends on:** RES-002
**Branch:** `feat/RES-003-scripts`

### Context
`make init` is mentioned in the README Quick Start but the implementation is absent or
incomplete. `make db-create` is new. These scripts are the operator's entry point.
Without them, a fresh clone cannot be started.

### Acceptance criteria

**`scripts/init.sh`:**
- [ ] Creates `authelia/secrets/` directory if absent
- [ ] Generates 5 secret files idempotently (does not overwrite existing):
  `JWT_SECRET`, `SESSION_SECRET`, `STORAGE_PASSWORD`, `STORAGE_ENCRYPTION_KEY`,
  `POSTGRES_SUPERUSER_PASSWORD`
- [ ] Uses `openssl rand -base64 64` (or `32` for shorter secrets)
- [ ] Prints next-step instructions: how to generate argon2id hash, how to update
  `users_database.yml`, how to set `VALKEY_PASSWORD` in `.env`
- [ ] Script is idempotent: running twice produces the same secrets, does not fail

**`scripts/db-create.sh`:**
- [ ] Reads superuser password from `authelia/secrets/POSTGRES_SUPERUSER_PASSWORD`
- [ ] Creates 4 databases with owners: `coder/coder`, `backstage/backstage`,
  `dojo/dojo`, `infisical/infisical`
- [ ] Reads per-plane passwords from `.env` variables (`CODER_DB_PASSWORD` etc.)
- [ ] Idempotent: `CREATE DATABASE IF NOT EXISTS` pattern (use `2>/dev/null || echo already exists`)
- [ ] Does NOT create the `authelia` database — that is handled separately by `make init`
  (see implementation note below)

**`Makefile`:**
- [ ] `init` target calls `scripts/init.sh`
- [ ] `up` target calls `docker compose up -d`; prints service URLs
- [ ] `down` target calls `docker compose down` (no `-v`)
- [ ] `down-volumes` target calls `docker compose down -v` with a `@echo WARNING: this destroys all data` line
- [ ] `db-create` target calls `scripts/db-create.sh`
- [ ] `logs-traefik` and `logs-authelia` targets
- [ ] `test` target calls `pytest tests/unit/ -v`
- [ ] `help` target with `##` comment parsing

### Implementation notes for Deepseek
**Authelia database bootstrap problem:** Authelia requires its `authelia` database
to exist before it starts. But `db-create.sh` runs after the stack is up. Solve this
in `init.sh`: after generating secrets, run:
```bash
# Start only postgres first
docker compose up -d fawkes-postgres
# Wait for health
until docker exec fawkes-postgres pg_isready -U postgres; do sleep 1; done
# Create authelia database
docker exec fawkes-postgres psql -U postgres \
  -c "CREATE USER authelia WITH PASSWORD '$(cat authelia/secrets/STORAGE_PASSWORD)';" 2>/dev/null || true
docker exec fawkes-postgres psql -U postgres \
  -c "CREATE DATABASE authelia OWNER authelia;" 2>/dev/null || true
# Bring down postgres — operator runs make up separately
docker compose stop fawkes-postgres
```
This pattern starts only Postgres, provisions Authelia's schema, then stops it.
The operator then runs `make up` to start the full stack. Document this clearly.

`openssl rand -base64 64` produces a 64-byte random value base64-encoded.
The output includes `\n` at the end — pipe through `tr -d '\n'` to remove it.

---

## RES-004 · Write docs and update README

**Type:** docs
**Estimated effort:** 1 hr
**Depends on:** RES-002, RES-003
**Branch:** `feat/RES-004-docs`

### Context
The README Quick Start is correct but thin. Downstream planes need a precise
copy-paste connection reference. This is also where the network name correction
is formally documented for all other plane authors. Closes the cross-repo correction.

### Acceptance criteria

**`docs/quickstart.md`:**
- [ ] Step 0: Prerequisites (Docker 24+, `openssl` available, ports 80 and 9091 free)
- [ ] Step 1: `make init` — what it does, what files it creates
- [ ] Step 2: Generate argon2id password hash (exact docker command)
- [ ] Step 3: Update `authelia/users_database.yml` with real hash
- [ ] Step 4: Copy `.env.example` to `.env`; set `VALKEY_PASSWORD` and per-plane DB passwords
- [ ] Step 5: `make up`
- [ ] Step 6: `make db-create`
- [ ] Step 7: Verify acceptance criteria (`curl` commands from spec §9)
- [ ] Troubleshooting: Authelia fails to start → check authelia DB exists;
  Traefik 404 → check `traefik.enable: true` label on downstream service

**`docs/connecting-downstream.md`:**
- [ ] Exact YAML block for downstream `compose.yaml` network attachment (from README)
- [ ] Table of service DNS names and ports (from spec §2.3)
- [ ] Valkey index partition table (from spec §6)
- [ ] Traefik label pattern for routing + Authelia protection (from design §3.2)
- [ ] Per-plane database connection strings with correct hostnames
- [ ] Statement: "The network is named `ufawkes-resources_fawkes-backbone-net`. Do not use `fawkes-net`."

**`docs/db-tenancy.md`:**
- [ ] Table of all databases, owners, created-by steps
- [ ] Statement: cross-plane SQL queries are prohibited; use service APIs

**`README.md` updates:**
- [ ] Version table: pin Traefik to `v3.7.5`, Authelia to verified tag, Postgres to `17-alpine`, Valkey to `8.1-alpine`
- [ ] Add link to `docs/connecting-downstream.md`
- [ ] Add `make db-create` to Quick Start steps

---

## Milestone summary

| Milestone | Issues | Target |
|---|---|---|
| **v0.2-tooling** | RES-001 | Week 3 |
| **v0.2-infra** | RES-002 | Week 3–4 |
| **v0.2-ops** | RES-003 | Week 4 |
| **v0.2-docs** | RES-004 | Week 4 |

**Dependency graph:**
```
RES-001 → RES-002 → RES-003 → RES-004
```
All issues are strictly sequential. No parallel work.

---

## Notes for Deepseek implementation

1. **The network name is the most critical correctness requirement.** Every reference
   to the Docker network in every file must use `fawkes-backbone-net` as the internal
   name and `ufawkes-resources_fawkes-backbone-net` as the external name. Never
   `fawkes-net`. Never `backbone-net`. These are exact strings.

2. **Authelia config fields are version-specific.** The field `authentication_backend`
   was renamed in some Authelia versions. The session `domain` field behaviour changed
   in v4.38. Always read the docs for the exact pinned version before writing
   `configuration.yml`.

3. **The Authelia database bootstrap is the hardest operational problem.** The
   `init.sh` solution (start Postgres alone, create DB, stop Postgres) is the correct
   approach for a single-node Docker Compose setup. Do not try to solve this with
   Postgres init scripts in the image — those only run on first start of a clean
   volume, which creates a race condition.

4. **Secret files must be git-ignored.** Add `authelia/secrets/` to `.gitignore`.
   The `authelia/secrets/` directory itself should be in `.gitignore`; the
   `authelia/` directory (containing `configuration.yml` and `users_database.yml`)
   should be tracked. Verify this distinction carefully before writing `.gitignore`.

5. **`valkey-cli -a` exposes password in process list.** This is known and acceptable
   for v0.2. Add a `# TODO v0.3: use --no-auth-warning and secrets file` comment
   on the healthcheck line in `compose.yaml`.

6. **Do not call `make db-create` from `make up`.** They are intentionally separate.
   `db-create` requires the stack to be healthy first; calling it from `up` creates
   a timing dependency that is fragile. Operators run them sequentially.