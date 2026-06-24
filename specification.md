# uFawkesRes — Specification v0.2
*Resource Plane of the Fawkes IDP Family*

**Status:** Draft — 2026-06-23
**Author:** Platform Engineering (solo contributor)
**Repo:** https://github.com/paruff/uFawkesRes

---

## ⚠ Critical correction to all prior session documents

Every prior document in this session used `fawkes-net` as the shared network name.
The uFawkesRes README specifies the actual network as:

- **Internal bridge name:** `fawkes-backbone-net`
- **Compose-qualified external name:** `ufawkes-resources_fawkes-backbone-net`

Downstream planes must attach using:
```yaml
networks:
  fawkes-backbone-net:
    name: ufawkes-resources_fawkes-backbone-net
    external: true
```

The DNS names for uFawkesRes services are:
- `fawkes-postgres:5432` (not `postgres:5432`)
- `fawkes-cache:6379` (not `valkey:6379`)
- `fawkes-sso:9091` (not `infisical:8082` — SSO is Authelia, not Infisical)

**All connection strings in uFawkesPipe, uFawkesSec, and uFawkesDevX documents must
be updated to use these names.** The fawkes-integration.md cross-repo document must
also be revised.

---

## Baseline state (observed from README, 2026-06-23)

| Item | Confirmed |
|---|---|
| Services | Traefik (ingress), Authelia (SSO), Postgres (shared DB), Valkey (cache) |
| Network | `fawkes-backbone-net` (bridge); external name `ufawkes-resources_fawkes-backbone-net` |
| Traefik host port | 80 |
| Authelia host port | 9091 |
| Quick start | `make init && make up` |
| Files visible in README | `compose.yaml`, `Makefile`, `.env.example` implied; `traefik/` and `authelia/` config dirs implied |
| Files confirmed absent | `traefik/traefik.yml`, `authelia/configuration.yml`, `tests/` — not mentioned in README |
| Downstream connect block | Documented in README |

---

## 1. Purpose and Scope

uFawkesRes is the resource plane — the foundation every other uFawkes plane depends on.
It starts first and shuts down last. It provides four capabilities:

| Capability | Service | What it gives downstream planes |
|---|---|---|
| **Ingress gateway** | Traefik v3 | Label-based routing, TLS termination (v0.3), Authelia ForwardAuth middleware |
| **SSO authentication** | Authelia | Single sign-on portal; ForwardAuth header forwarding to all planes |
| **Shared database** | Postgres 17 | One DB server, separate schemas per tenant; zero per-plane DB infrastructure |
| **Shared cache** | Valkey 8 | Redis-compatible; session storage for Authelia; available to all planes |

### 1.1 What v0.2 adds to the existing baseline

The README describes a working v0.1 stack. v0.2 adds:

| Addition | Rationale |
|---|---|
| Pinned image versions in `compose.yaml` | Traefik and Authelia are active projects; `:latest` is a stability risk |
| `traefik/traefik.yml` static config committed to repo | Currently implied but not shown; required for Traefik v3 Docker provider and dashboard |
| `authelia/configuration.yml` baseline committed to repo | Currently implied but not shown; Authelia will not start without it |
| `authelia/users_database.yml` with one admin user | Minimum viable user store for local dev |
| Authelia secrets via Docker secrets (not env vars) | Four Authelia secrets should never appear in `docker inspect` output |
| `make init` target defined explicitly | README mentions it but the Makefile target must actually create the required data directories and seed the config files |
| `make db-create` target | Creates per-plane databases and users in Postgres after first boot |
| Health check endpoints documented | README shows `curl` commands; compose healthchecks must match |
| `tests/` directory with structural contract tests | No tests exist; `pytest` validation of compose structure and config files |
| `.pre-commit-config.yaml` | Not mentioned in README; required for consistency with other planes |

### 1.2 Out of scope for v0.2

- TLS/HTTPS (port 443, Let's Encrypt) — v0.3; requires a domain or self-signed cert setup
- Authelia LDAP or OIDC provider configuration — file-based user store sufficient for local dev
- Postgres replication or HA — single-node only
- Valkey persistence tuning — default `appendonly yes` is sufficient
- PgBouncer connection pooling — revisit if connection count becomes a problem at v0.3
- pgAdmin or other database admin UI — operator uses `psql` directly for v0.2

---

## 2. Services

### 2.1 Service table

| Service name (DNS) | Image | Host port | Role |
|---|---|---|---|
| `traefik` | `traefik:v3.7.5` | `80` (HTTP), `8080` (dashboard) | Ingress gateway; reverse proxy for all planes |
| `fawkes-sso` | `authelia/authelia:4.38.17` ⚠ | `9091` | SSO portal; ForwardAuth middleware |
| `fawkes-postgres` | `postgres:17-alpine` | `5432` (host, dev only) | Shared PostgreSQL server |
| `fawkes-cache` | `valkey/valkey:8.1-alpine` | `6379` (host, dev only) | Shared Valkey cache |

**⚠ Authelia version:** `4.38.17` is the highest pinned tag visible on Docker Hub as of
this writing. The Authelia releases page shows active development with frequent patches.
**Verify the current stable tag at https://github.com/authelia/authelia/releases before
implementing RES-002.** Do not use `:latest`.

**Valkey version:** `valkey/valkey:8.1-alpine` — Valkey 8.x is the current stable line
as of mid-2025. Verify at https://hub.docker.com/r/valkey/valkey before implementing.

### 2.2 Bootstrap ordering problem — Authelia depends on its own plane's services

Authelia requires:
- Postgres (for its own `authelia` database) to be healthy before it starts
- Valkey (for session storage) to be healthy before it starts

Both are in the same `compose.yaml`. This means:

```
fawkes-postgres (healthcheck: pg_isready)
  └─depends_on─► fawkes-cache (healthcheck: valkey-cli ping)
      └─depends_on─► fawkes-sso (Authelia)
          └─depends_on─► traefik
```

`compose.yaml` must declare `depends_on` with `condition: service_healthy` for all four
services. Traefik does not depend on any other service.

### 2.3 DNS names (confirmed from README)

Downstream planes reach uFawkesRes services by these container names on
`ufawkes-resources_fawkes-backbone-net`:

| What you are connecting to | Connection string |
|---|---|
| Postgres | `postgresql://<user>:<pass>@fawkes-postgres:5432/<db>` |
| Valkey | `redis://fawkes-cache:6379/<index>` |
| Authelia SSO | `http://fawkes-sso:9091` |
| Traefik dashboard (internal) | `http://traefik:8080` |

---

## 3. Authelia configuration requirements

Authelia v4.38+ requires these files at startup (mounted into the container at `/config/`):

| File | Required? | Contents |
|---|---|---|
| `authelia/configuration.yml` | **Yes** — Authelia will not start without it | Storage backend (Postgres), session backend (Valkey), access control rules, SMTP (optional) |
| `authelia/users_database.yml` | Yes (for file-based auth) | At least one admin user with hashed password |

Authelia also requires four secrets injected via Docker secrets or `_FILE` env vars:

| Secret | Env var (`_FILE` suffix) | Purpose |
|---|---|---|
| `authelia_jwt_secret` | `AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE` | JWT signing key |
| `authelia_session_secret` | `AUTHELIA_SESSION_SECRET_FILE` | Session encryption |
| `authelia_storage_password` | `AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE` | Authelia's Postgres password |
| `authelia_storage_encryption_key` | `AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE` | Storage encryption |

These must be generated before `make up`. The `make init` target must generate them.

---

## 4. Traefik configuration requirements

Traefik v3 requires a static configuration file. The Docker provider and dashboard
must be explicitly enabled.

`traefik/traefik.yml` minimum required content:
```yaml
api:
  dashboard: true
  insecure: true          # dashboard on :8080 without auth; acceptable for local dev

providers:
  docker:
    exposedByDefault: false   # only route containers with traefik.enable=true label
    network: fawkes-backbone-net

entryPoints:
  web:
    address: ":80"
```

Traefik mounts `/var/run/docker.sock` to discover downstream service labels automatically.

---

## 5. Per-plane database tenancy

`make db-create` provisions these databases and users after first boot.
uFawkesRes does not auto-create them at startup.

| Database | User | Created for |
|---|---|---|
| `authelia` | `authelia` | Authelia internal storage |
| `coder` | `coder` | Coder control plane (uFawkesDevX) |
| `backstage` | `backstage` | Backstage backend (uFawkesDevX) |
| `dojo` | `dojo` | DefectDojo (uFawkesSec) |
| `infisical` | `infisical` | Infisical (uFawkesSec) |

The `authelia` database must exist before `make up` on a fresh install — it is needed
by the Authelia container before other planes start. `make init` creates it.
All others are created by `make db-create` after the stack is up.

---

## 6. Valkey index partitioning

| Index | Used by | Connection string |
|---|---|---|
| `0` | Authelia sessions | `redis://fawkes-cache:6379/0` |
| `1` | DefectDojo Celery broker (uFawkesSec) | `redis://fawkes-cache:6379/1` |
| `2` | Infisical (uFawkesSec) | `redis://fawkes-cache:6379/2` |
| `3–9` | Reserved for app workloads via Score | configured per workload |

---

## 7. Downstream connection pattern

From the README, confirmed connection block for all downstream planes:

```yaml
# In any downstream plane's compose.yaml:
networks:
  fawkes-backbone-net:
    name: ufawkes-resources_fawkes-backbone-net
    external: true
```

All services in the downstream plane that need uFawkesRes access must declare
`networks: [fawkes-backbone-net]`.

Traefik label pattern for a downstream service to be routed and SSO-protected:

```yaml
labels:
  traefik.enable: "true"
  traefik.http.routers.myservice.rule: "Host(`myservice.localhost`)"
  traefik.http.routers.myservice.entrypoints: "web"
  traefik.http.routers.myservice.middlewares: "authelia@docker"
  traefik.http.services.myservice.loadbalancer.server.port: "8080"
```

The `authelia@docker` middleware is defined by labels on the Authelia container in
uFawkesRes. Downstream planes do not configure Authelia — they only reference it.

---

## 8. Non-Functional Requirements

| Concern | Requirement |
|---|---|
| **Startup first** | uFawkesRes must be fully healthy before any other plane starts |
| **Shutdown last** | `make down` on uFawkesRes must be the last command in any teardown |
| **RAM budget** | Traefik ~50MB, Authelia ~80MB, Postgres ~200MB, Valkey ~50MB — total < 400MB |
| **Idempotency** | `make down && make up` restores clean state; Postgres data persists in named volume |
| **Secret generation** | `make init` generates all required secrets and config files; idempotent (does not overwrite existing) |
| **Image pinning** | All images pinned to specific versions; no `:latest` |
| **Pre-commit** | `gitleaks`, `yamllint`, `markdownlint`, `prettier` run on every commit |
| **Test coverage** | `pytest tests/unit/` validates compose structure, config file presence, and secret file existence |

---

## 9. Acceptance Criteria

1. `make init` completes without error on a clean clone; required config files and secret files exist afterward.
2. `make up` starts all 4 services with no errors.
3. `curl -f http://localhost:80/ping` returns 200 (Traefik).
4. `curl -f http://localhost:9091/api/health` returns 200 (Authelia).
5. `psql -h localhost -U postgres -c "\l"` lists at least the `authelia` database.
6. `docker run --rm --network ufawkes-resources_fawkes-backbone-net valkey/valkey:8.1-alpine valkey-cli -h fawkes-cache ping` returns `PONG`.
7. Accessing `http://localhost/` via browser redirects to the Authelia portal.
8. `pytest tests/unit/` passes with zero failures.
9. `pre-commit run --all-files` passes.

---

## 10. Open Questions

| # | Question | Blocks |
|---|---|---|
| Q1 | Current Authelia stable patch version — verify at github.com/authelia/authelia/releases | RES-002 |
| Q2 | Does the existing repo have `traefik/traefik.yml` and `authelia/configuration.yml`? README implies them but does not show them | RES-002 |
| Q3 | What domain/hostname is used for Traefik routing rules? `*.localhost` for local dev or a real LAN hostname? | RES-003 |
| Q4 | Should Postgres port 5432 be exposed to the host? Convenient for dev but a security concern | RES-002 |