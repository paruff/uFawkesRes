# Contributing to uFawkesObs

Thanks for your interest in contributing to uFawkesObs — the self-hosted observability plane for the Fawkes IDP.

## Reporting Bugs

Open a [GitHub issue](https://github.com/paruff/uFawkesObs/issues/new?template=bug_report.md) with the bug template. Include:

- What you expected to happen vs. what actually happened
- Steps to reproduce
- `docker compose ps` output
- `docker compose logs <service>` output for the affected service
- Your OS and Docker version

## Suggesting Features

Open a [GitHub issue](https://github.com/paruff/uFawkesObs/issues/new?template=feature_request.md) with the feature template. Link it to the wave or milestone it belongs to if known.

## Submitting a Pull Request

1. **Fork** the repository
2. **Create a branch** from `main`:
   - `fix/<description>` for bug fixes
   - `feat/<description>` for new features
3. **Make your changes** — one logical change per PR
4. **Run tests** before opening the PR:
   ```bash
   make test-unit
   ```
5. **Open a PR** against `main`. The PR description must include:
   - What changed (one sentence per service affected)
   - Services affected and how tested
   - Secrets check: confirmed nothing sensitive committed

## Development Setup

```bash
git clone https://github.com/paruff/uFawkesObs.git
cd uFawkesObs
cp .env.example .env
make init
make up
pytest tests/unit/ -v
```

This starts the full stack (Prometheus, Grafana, Loki, Tempo, OTel Collector, Alertmanager, Alloy) and runs the unit tests. No external services required.

## Code Conventions

### Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
fix(prometheus): correct scrape interval
feat(grafana): add DORA dashboard
docs: update README
test(loki): add schema validation
```

**Valid scopes:** `prometheus`, `otel`, `loki`, `tempo`, `grafana`, `alloy`, `alertmanager`, `scripts`, `docs`, `ci`

### YAML

- 2-space indentation, no tabs
- `yamllint` must pass
- Quoted strings for values that could be misread as other types

### Shell Scripts

- `set -euo pipefail` at the top of every script
- `shellcheck` must pass
- No hardcoded container names

### Docker Compose

- All image versions must be pinned — no `:latest` tags
- All services must have `healthcheck:` defined
- Secrets go in `.env` (gitignored) — never in `compose.yaml`

## What We Don't Accept

- **Bundled multi-component upgrades** in a single PR — upgrade one service at a time
- **`:latest` image tags** — all versions must be pinned to a specific patch
- **Credentials or secrets** in any file — use `.env` and environment variable substitution
- **Direct pushes to `main`** — all changes go through PRs

## Running the Full Test Suite

```bash
make test-unit         # Unit tests (no running stack needed)
make test-acceptance   # Acceptance tests (requires: make up)
make test              # Both
```

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you agree to uphold its standards.

## License

By contributing, you agree that your contributions will be licensed under the
[Apache License 2.0](LICENSE).
