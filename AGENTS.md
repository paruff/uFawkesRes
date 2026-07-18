# Agent Instructions — uFawkesRes

> Universal instructions for all agents: GitHub Copilot, VS Code agent mode, Claude.
> uFawkesRes is the **Resource Plane** of the Fawkes IDP family.
> It provides Traefik ingress, Authelia SSO, PostgreSQL, and Valkey cache via Docker Compose.
> **Do not modify this file without maintainer approval.**

---

## 1. Stack Identity

uFawkesRes is the Resource Plane of the [Fawkes IDP](https://github.com/paruff/fawkes) family — a Docker Compose stack that provides shared infrastructure services. Downstream planes (uFawkesObs, uFawkesPipe, uFawkesDevX) attach to the `fawkes-backbone-net` bridge network to consume these services.

**Services:**

| Service         | Image                    | Container Name  | Role                                                     |
| --------------- | ------------------------ | --------------- | -------------------------------------------------------- |
| ingress-gateway | traefik:v3.0             | fawkes-ingress  | Reverse proxy, entry point for all HTTP traffic          |
| sso-auth        | authelia/authelia:latest | fawkes-sso      | Single sign-on, 2FA, session management                  |
| shared-postgres | postgres:16-alpine       | fawkes-postgres | Shared relational database for SSO and downstream planes |
| cache-backend   | valkey/valkey:7.2-alpine | fawkes-cache    | In-memory cache, session store, rate-limit backing       |

**Network:** `fawkes-backbone-net` (bridge) — all services attach to this network. Downstream planes connect by declaring it as `external: true`.

**Repository:** github.com/paruff/uFawkesRes

---

## 2. Docker Compose Constraints

### compose.yaml

- All service image versions **pinned** — no `latest` tags (Authelia is the sole exception as it is the Authelia maintainers' recommended pattern)
- Secrets and passwords go in `.env` (gitignored) — never in `compose.yaml`
- All passwords via `${VAR:?}` mandatory env var references
- Networks explicitly declared — no implicit default network
- Persistent data mounts use bind mounts to `./data/`
- Initialization scripts mount at `./init-scripts:/docker-entrypoint-initdb.d:ro`

### config/

- Traefik configuration in `config/traefik/traefik.yml`
- Authelia configuration in `config/authelia/configuration.yml`
- Authelia users database in `config/authelia/users_database.yml`
- No credentials in config files — use `${VAR}` environment variable substitution
- Authelia uses file-based auth (no LDAP), SQLite storage (no external DB), filesystem notifier (no SMTP)

### scripts/

- `set -euo pipefail` at the top of every `.sh` file
- `shellcheck` must pass on all scripts
- Check-env validates `SHARED_DB_PASSWORD`, `AUTHELIA_JWT_SECRET`, `AUTHELIA_SESSION_SECRET` are set and not `changeme`
- Health checks poll Traefik (`:80/ping`) and Authelia (`:9091/api/health`)

### Initialization

- First boot: PostgreSQL runs `init-scripts/01-create-databases.sql` to create `sonar_db`, `dojo_db`, `dora_db`, `infisical_db`
- Re-run: `rm -rf data/postgres && make init && make up`

---

## 3. Agent Roles

| Agent                     | Responsibilities                                                                |
| ------------------------- | ------------------------------------------------------------------------------- |
| **Workflow orchestrator** | Classifies issues into workflows (A/B/C/D), selects lifecycle, validates inputs |
| **Spec agent**            | Extracts requirements and acceptance criteria from user intent                  |
| **Design agent**          | Converts specification into technical design, components, interfaces            |
| **Plan agent**            | Decomposes work into sequenced, bounded tasks with dependencies                 |
| **Build agent**           | Turns plan into code, manifests, pipeline configurations                        |
| **Review agent**          | Validates output against spec, design, quality, and governance                  |
| **Test agent**            | Writes and executes tests; validates acceptance criteria                        |

---

## 4. Architecture Rules — Never Violate These

### General

- `compose.yaml` is the single source of truth for service definitions
- `.env` is gitignored — never commit it
- All new services must join the `fawkes-backbone-net` network
- No hardcoded IP addresses or port numbers in config files

### Downstream Integration

- Other uFawkes planes connect via `fawkes-backbone-net` declared as `external: true`
- Services are reachable by container name (`fawkes-postgres:5432`, `fawkes-cache:6379`, `fawkes-sso:9091`)
- No plane should depend on another plane's internal configuration

---

## 5. The PM–Agent Contract

### Agents MAY Do Without Asking

- Read any file
- Edit `config/`, `scripts/`, `init-scripts/`, `docs/`
- Run: `docker compose config`, `yamllint`, `shellcheck`, `markdownlint`
- Open draft PRs

### Agents MUST Ask Before

- Changing image versions in `compose.yaml`
- Adding or removing services from `compose.yaml`
- Changing exposed port numbers
- Modifying volume mount paths
- Adding new environment variables to `compose.yaml`
- Changing Authelia or Traefik configuration structure

### Agents Must NEVER

- Commit `.env` files, passwords, API keys, or tokens
- Remove `restart: unless-stopped` from any service
- Push to `main` directly or merge their own PRs
- Modify `AGENTS.md` without maintainer approval

---

## 6. Coding Standards

### YAML (all files)

- `yamllint` must pass (config in `.yamllint.yml`)
- 2-space indentation, no tabs
- Quoted strings for values that could be misread as other types

### Bash (scripts/)

- `set -euo pipefail` at top
- `shellcheck` must pass
- Functions over repeated blocks
- Descriptive variable names in UPPER_SNAKE_CASE

### SQL (init-scripts/)

- Each database creation is a single `CREATE DATABASE` statement
- Prefix files with `NN-` for deterministic ordering
- Include a header comment explaining when the file runs

### Commits

- Scope prefix matching issue: `fix(infra):`, `docs(infra):`, `docs(agents):`
- Reference issue number when applicable

---

## 7. PR Requirements

Every PR must include the AI-Assisted Review Block:

- What changed (one sentence per service affected)
- Services affected and how tested (`docker compose config` + smoke tests)
- Any port or volume changes flagged
- Secrets check: confirmed nothing sensitive committed

---

## 8. GitOps Principles & Trunk-Based Delivery

### Branch Discipline

- All work happens on feature branches off `main` (trunk-based development, short-lived)
- Branch naming: `<type>/<slug>` (see `docs/PR_STANDARD.md`)
- Never commit directly to `main`
- Every branch opens a PR through CI gates before merge

### Deployment Lifecycle Gates

1. **Main CI must be green before any PR merges.** Enforced by `main-ci-guard.yml` calling `paruff/ufawkespipe/.github/workflows/reusable-main-ci-guard.yml@v1.2.0`, which verifies the `ci.yml` workflow (with `workflow-id: ci.yml` and `workflow-name: "CI"`) passed on the PR branch before allowing merge to `main`.
2. **Observability is built-in.** All CI jobs emit `job-start` / `job-finish` timestamps as the first and last steps, enabling traceability of build times, test results, and deploy status.

### PR Gates Are Deploy Gates

- Every merge to `main` is a deploy candidate
- Broken `main` blocks all PRs — fix main CI before merging anything else

### Rollback

- Rollback is `git revert` to a previous commit
- The primary rollback mechanism is reverting the merge commit

---

## 9. Context Files

| Pri | File | Why |
|-----|------|-----|
| 1 | `compose.yaml` | service definitions and versions |
| 2 | `AGENTS.md` | agent instructions (this file) |
| 3 | `.github/workflows/ci.yml` | CI pipeline definition |
| 4 | `.github/workflows/main-ci-guard.yml` | main branch CI guard |
| 5 | `.env.example` | required environment variables |
| 6 | `Makefile` | common commands and workflows |
| 7 | `docs/PR_STANDARD.md` | PR naming and CI requirements |

---

## 10. Issue Tracker

| Issue | Description                                                                    | Status      | Files                                                                                                   |
| ----- | ------------------------------------------------------------------------------ | ----------- | ------------------------------------------------------------------------------------------------------- |
| R1    | Create `compose.yaml` skeleton with four service stubs                         | ✅ COMPLETE | `compose.yaml`                                                                                          |
| R2    | Create `.env.example`, `README.md`, and `catalog-info.yaml`                    | ✅ COMPLETE | `.env.example`, `README.md`, `catalog-info.yaml`                                                        |
| R3    | Create `Makefile` with init, check-env, up, down, status, test, pr targets     | ✅ COMPLETE | `Makefile`                                                                                              |
| R4    | Create `scripts/` — check-env.sh, wait-healthy.sh, smoke-test.sh, pr-create.sh | ✅ COMPLETE | `scripts/check-env.sh`, `scripts/wait-healthy.sh`, `scripts/smoke-test.sh`, `scripts/pr-create.sh`      |
| R5    | Create `init-scripts/01-create-databases.sql` and PostgreSQL init bootstrap    | ✅ COMPLETE | `init-scripts/01-create-databases.sql`                                                                  |
| R6    | Create Authelia and Traefik config files                                       | ✅ COMPLETE | `config/traefik/traefik.yml`, `config/authelia/configuration.yml`, `config/authelia/users_database.yml` |
| R7    | Create `.github/workflows/ci.yml` adapted from uFawkesObs                      | ✅ COMPLETE | `.github/workflows/ci.yml`                                                                              |
| R8    | Create `AGENTS.md` with all issues registered                                  | ✅ COMPLETE | `AGENTS.md`                                                                                             |
| R9    | Add GitOps lifecycle gates: main-ci-guard.yml, PR_STANDARD.md, timestamps     | ✅ COMPLETE | `.github/workflows/main-ci-guard.yml`, `docs/PR_STANDARD.md`, `.github/workflows/ci.yml`, `AGENTS.md`   |

---

## 11. Service Endpoints & Ports

| Service    | Internal Port | External Port | Health Endpoint |
| ---------- | ------------- | ------------- | --------------- |
| Traefik    | 80            | 80            | `/ping`         |
| Authelia   | 9091          | 9091          | `/api/health`   |
| PostgreSQL | 5432          | —             | —               |
| Valkey     | 6379          | —             | —               |

---

## 12. Reproducible First Boot Sequence

```bash
cp .env.example .env
$EDITOR .env              # Set SHARED_DB_PASSWORD, AUTHELIA_JWT_SECRET, AUTHELIA_SESSION_SECRET
make init                 # Create data/ directories
make up                   # Start all services (validates .env first)
./scripts/wait-healthy.sh # Wait for Traefik + Authelia health checks
```

On a clean system, this is the only sequence required.

---

## 13. Integration with Other Planes

uFawkesRes is designed to be consumed by:

- **uFawkesObs** — Connects to `fawkes-backbone-net` as `external: true` to reach PostgreSQL
- **uFawkesPipe** — CI/CD plane uses Traefik ingress, PostgreSQL storage
- **uFawkesDevX** — Developer tooling uses Authelia SSO, Valkey cache
- **fawkes** — Full IDP deployment uses uFawkesRes as the shared resource substrate

When making changes, check whether cross-plane consumers will be affected.

---

## 14. Handoff Block

**Current branch:** `master`
**Last completed issue:** R9 — GitOps lifecycle gates
**Outstanding items:** None

### Handoff instructions for the next agent session

1. Read `AGENTS.md` (this file) for full stack context before making any changes
2. Read `compose.yaml` for current service definitions and versions
3. Run `yamllint .` and `shellcheck scripts/*.sh` before committing
4. Never commit `.env` files or hardcoded secrets
5. All new services must join the `fawkes-backbone-net` network
6. The CI workflow (`ci.yml`) validates the stack on every push to `master` and every PR
7. Smoke tests run on manual `workflow_dispatch` only (requires Docker host)
8. To re-bootstrap PostgreSQL: `rm -rf data/postgres && make init && make up`
