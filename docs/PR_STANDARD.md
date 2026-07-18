# PR Standard — uFawkesRes

## Conventional Commits

Every PR title **must** follow the Conventional Commits format:

```
type(scope): description
```

### Types

| Type     | Usage                                        |
| -------- | -------------------------------------------- |
| `feat`   | New service, config, or capability           |
| `fix`    | Bug fix                                      |
| `docs`   | Documentation only                           |
| `chore`  | Maintenance, tooling, CI, dependencies       |
| `refactor` | Code change with no functional difference  |
| `test`   | Adding or fixing tests                       |

### Scope

Use the most specific scope that describes the change:

| Scope          | Area                                              |
| -------------- | ------------------------------------------------- |
| `infra`        | compose.yaml, Traefik, Authelia, PostgreSQL, etc. |
| `ci`           | Workflows, GitHub Actions config                  |
| `agents`       | AGENTS.md, agent instructions                     |
| `docs`         | README, docs/ files                               |
| `scripts`      | Shell scripts in scripts/                         |

### Description

- Lowercase after the scope prefix
- Imperative mood ("add", "fix", "remove", not "added", "fixed")
- No period at the end
- Keep under 72 characters

**Examples:**

```
feat(infra): add Redis healthcheck config
fix(infra): pin valkey image to 7.2-alpine
docs(infra): document Authelia SSO setup
chore(ci): add dependency-review stage
```

## Branch Naming

- All work on feature branches off `main`
- Branch naming: `<type>/<slug>`
- Examples: `feat/add-valkey-healthcheck`, `fix/pin-traefik-version`, `chore/update-ci-workflow`
- Never commit directly to `main`

## PR Requirements

1. Title must follow Conventional Commits format
2. Description must include the **AI-Assisted Review Block**:
   - What changed (one sentence per service affected)
   - Services affected and how tested (`docker compose config` + smoke tests)
   - Any port or volume changes flagged
   - Secrets check: confirmed nothing sensitive committed
3. All CI checks must pass before merge
4. At least one reviewer must approve
5. No self-merge

## CI Requirements

- `main-ci-guard.yml` enforces that `ci.yml` is green before any PR merges to `main`
- All CI jobs emit `job-start` / `job-finish` timestamps for observability
- Pipeline must pass all stages: preflight, lint, build, security, dependency-review, tests

## Definition of Done

- [ ] PR title follows Conventional Commits
- [ ] CI pipeline green
- [ ] `main-ci-guard` check passed
- [ ] At least one review approval
- [ ] AI-Assisted Review Block included
- [ ] No secrets committed
- [ ] Documentation updated if applicable
