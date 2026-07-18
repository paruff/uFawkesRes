# uFawkesRes

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Part of Fawkes IDP](https://img.shields.io/badge/Part%20of-Fawkes%20IDP-purple.svg)](https://github.com/paruff/fawkes)

## What This Is

uFawkesRes is the **Resource Plane** of the [Fawkes IDP](https://github.com/paruff/fawkes). It provides the shared infrastructure services that downstream planes (uFawkesObs, uFawkesPipe, etc.) depend on: an **ingress gateway** (Traefik), **SSO authentication** (Authelia), a **shared PostgreSQL** database, and a **Valkey cache** — all wired together on the `fawkes-backbone-net` bridge network.

Think of it as the power strip and backhaul your observability, CI/CD, and developer planes plug into.

## Prerequisites

- **Docker** 24+
- **Docker Compose** v2+
- Ports 80 (Traefik) and 9091 (Authelia) available

## Quick Start

```bash
# 1. Clone and enter
git clone https://github.com/paruff/uFawkesRes.git
cd uFawkesRes

# 2. Create and configure environment variables
cp .env.example .env
$EDITOR .env

# 3. Create data directories and start the stack
make init && make up
```

## Ports

| Service      | Port | Purpose            | Access URL            |
| ------------ | ---- | ------------------ | --------------------- |
| **Traefik**  | 80   | Ingress gateway    | http://localhost:80   |
| **Authelia** | 9091 | SSO authentication | http://localhost:9091 |

## Health Checks

```bash
# Check Traefik
curl -f http://localhost:80/ping

# Check Authelia
curl -f http://localhost:9091/api/health
```

## Connecting a Downstream Plane

Other uFawkes stacks connect to the Resource Plane by attaching to the `fawkes-backbone-net` external network. Add this block to their `compose.yaml`:

```yaml
networks:
  fawkes-backbone-net:
    name: ufawkes-resources_fawkes-backbone-net
    external: true
```

Services in the downstream plane can then reach `fawkes-postgres:5432`, `fawkes-cache:6379`, and `fawkes-sso:9091` by container name.

## uFawkes Stack Ecosystem

uFawkesRes is part of the [uFawkes](https://ufawkes.dev) platform engineering ecosystem:

| Stack           | Description                                          | Link                                            |
| --------------- | ---------------------------------------------------- | ----------------------------------------------- |
| **uFawkesRes**  | Resources — ingress, SSO, Postgres, Valkey           | [GitHub](https://github.com/paruff/uFawkesRes)  |
| **uFawkesObs**  | Observability — Prometheus, Grafana, AI dashboards   | [GitHub](https://github.com/paruff/uFawkesObs)  |
| **uFawkesPipe** | CI/CD — Jenkins, Buildpacks, DevSecOps               | [GitHub](https://github.com/paruff/ufawkespipe) |
| **uFawkesDORA** | DORA metrics — dashboards, VSM, delivery performance | [GitHub](https://github.com/paruff/ufawkesdora) |
| **uFawkesSec**  | Security — policy-as-code, supply chain, guardrails  | [GitHub](https://github.com/paruff/ufawkessec)  |
| **uFawkesDevX** | Developer experience — golden paths, IDP templates   | [GitHub](https://github.com/paruff/ufawkesdevx) |
| **uFawkesAI**   | AI agent templates — golden path scaffolding         | [GitHub](https://github.com/paruff/ufawkesai)   |
