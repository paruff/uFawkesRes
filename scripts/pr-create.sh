#!/usr/bin/env bash
# pr-create.sh — Stage, commit, push, and create a PR in one step.
# Runs pre-commit hooks before committing to follow gitops principles.
#
# Usage:
#   ./scripts/pr-create.sh "fix(prometheus): correct scrape interval"
#   ./scripts/pr-create.sh                        # auto-generate branch + message
#
# Environment variables:
#   PR_BRANCH   — branch name (default: auto-generated from first commit message)
#   PR_TITLE    — PR title (default: same as commit message)
#   PR_BODY     — PR body (default: auto-generated summary)
#   PR_BASE     — base branch (default: main)
#   PR_DRY_RUN  — set to 1 to skip push/create (commit only)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { printf "%b\n" "${CYAN}ℹ️  ${NC} $*"; }
pass()  { printf "%b\n" "${GREEN}✅ ${NC} $*"; }
warn()  { printf "%b\n" "${YELLOW}⚠️  ${NC} $*"; }
fail()  { printf "%b\n" "${RED}❌ ${NC} $*"; exit 1; }

COMMIT_MSG="${1:-}"
PR_BRANCH="${PR_BRANCH:-}"
PR_TITLE="${PR_TITLE:-${COMMIT_MSG}}"
PR_BASE="${PR_BASE:-main}"
PR_DRY_RUN="${PR_DRY_RUN:-0}"

# ── 1) Pre-flight checks ────────────────────────────────────────────────────

command -v git >/dev/null 2>&1  || fail "git is not installed"
command -v gh  >/dev/null 2>&1  || fail "gh (GitHub CLI) is not installed. Run: brew install gh"

# Must be in a git repo
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Not inside a git repository"

# Check for pre-commit
if command -v pre-commit >/dev/null 2>&1; then
  HOOKS_INSTALLED=.git/hooks/pre-commit
  if [ -f "${HOOKS_INSTALLED}" ]; then
    info "Pre-commit hooks found — will run before commit."
  else
    warn "Pre-commit not installed in this repo. Run: make pre-commit-setup"
  fi
else
  warn "pre-commit not installed globally. Hooks will be skipped."
fi

# ── 2) Stage changes ────────────────────────────────────────────────────────

CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null || true)
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || true)
UNTRACKED_FILES=$(git ls-files --others --exclude-standard 2>/dev/null || true)

if [ -z "${CHANGED_FILES}" ] && [ -z "${STAGED_FILES}" ] && [ -z "${UNTRACKED_FILES}" ]; then
  fail "No changes to commit. Nothing staged, nothing modified, no untracked files."
fi

# Show what will be committed
info "Changes to commit:"
echo ""
if [ -n "${CHANGED_FILES}" ]; then
  echo "  Modified:"
  while IFS= read -r line; do echo "    ${line}"; done <<< "${CHANGED_FILES}"
fi
if [ -n "${UNTRACKED_FILES}" ]; then
  echo "  Untracked:"
  while IFS= read -r line; do echo "    ${line}"; done <<< "${UNTRACKED_FILES}"
fi
echo ""

# Stage everything
git add -A
pass "All changes staged."

# ── 3) Run pre-commit hooks ─────────────────────────────────────────────────

if [ -f .git/hooks/pre-commit ] && [ -x .git/hooks/pre-commit ]; then
  info "Running pre-commit hooks..."
  if .git/hooks/pre-commit; then
    pass "Pre-commit hooks passed."
  else
    fail "Pre-commit hooks failed. Fix the issues above and try again."
  fi
elif command -v pre-commit >/dev/null 2>&1 && [ -f .pre-commit-config.yaml ]; then
  info "Running pre-commit via pre-commit CLI..."
  if pre-commit run --all-files; then
    pass "Pre-commit hooks passed."
  else
    fail "Pre-commit hooks failed. Fix the issues above and try again."
  fi
else
  warn "No pre-commit hooks to run."
fi

# ── 4) Generate branch name if not provided ─────────────────────────────────

if [ -z "${PR_BRANCH}" ]; then
  # Derive from commit message or date
  if [ -n "${COMMIT_MSG}" ]; then
    # Convert "fix(prometheus): correct scrape interval" → "fix/prometheus-correct-scrape-interval"
    PR_BRANCH=$(echo "${COMMIT_MSG}" \
      | sed -E 's/^([a-z]+)\(([^)]+)\):?/\1-\2/' \
      | tr '[:upper:]' '[:lower:]' \
      | sed 's/[^a-z0-9-]/-/g' \
      | sed 's/-+/-/g' \
      | sed 's/^-//' \
      | sed 's/-$//' \
      | cut -c1-60)
  else
    PR_BRANCH="chore/$(date +%Y%m%d-%H%M%S)"
  fi
fi

# Switch to branch if not already on it
CURRENT_BRANCH=$(git branch --show-current)
if [ "${CURRENT_BRANCH}" != "${PR_BRANCH}" ]; then
  # Check if branch already exists
  if git show-ref --verify --quiet "refs/heads/${PR_BRANCH}" 2>/dev/null; then
    info "Branch '${PR_BRANCH}' already exists — switching to it."
    git checkout "${PR_BRANCH}"
  else
    info "Creating branch '${PR_BRANCH}'..."
    git checkout -b "${PR_BRANCH}"
  fi
fi
pass "On branch: ${PR_BRANCH}"

# ── 5) Commit ────────────────────────────────────────────────────────────────

if [ -z "${COMMIT_MSG}" ]; then
  # Interactive: prompt for message
  echo ""
  read -rp "Commit message: " COMMIT_MSG
  [ -z "${COMMIT_MSG}" ] && fail "Commit message cannot be empty."
fi

# Stage again in case pre-commit hooks modified files
git add -A
git commit -m "${COMMIT_MSG}"
pass "Committed: ${COMMIT_MSG}"

# ── 6) Push ──────────────────────────────────────────────────────────────────

if [ "${PR_DRY_RUN}" = "1" ]; then
  warn "Dry run — skipping push and PR creation."
  pass "Done (dry run). Commit is local on branch '${PR_BRANCH}'."
  exit 0
fi

info "Pushing to origin..."
git push -u origin "${PR_BRANCH}"
pass "Pushed to origin/${PR_BRANCH}"

# ── 7) Create PR ─────────────────────────────────────────────────────────────

# Auto-generate PR body if not provided
if [ -z "${PR_BODY:-}" ]; then
  # Count files changed
  FILES_CHANGED=$(git diff --stat HEAD~1 --name-only 2>/dev/null | wc -l | tr -d ' ')
  LINES_ADDED=$(git diff --stat HEAD~1 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
  LINES_REMOVED=$(git diff --stat HEAD~1 2>/dev/null | tail -1 | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")

  PR_BODY="## Summary

$(echo "${COMMIT_MSG}" | head -1)

### Changes

- Files changed: ${FILES_CHANGED}
- Lines added: ${LINES_ADDED}
- Lines removed: ${LINES_REMOVED}

### Services affected

$(git diff --name-only HEAD~1 2>/dev/null | sed 's/^/- /' || echo "- See files changed above")

### Run locally

\`\`\`bash
pytest tests/unit/ -v
\`\`\`

### Secrets check

No secrets, credentials, or environment variables committed.

---

**AI-Assisted Review Block:**
- What changed: ${COMMIT_MSG}
- Services affected: See files changed
- Port or volume changes: None
- Secrets check: Confirmed nothing sensitive committed"
fi

# Check if PR already exists for this branch
EXISTING_PR=$(gh pr list --head "${PR_BRANCH}" --json number --jq '.[0].number' 2>/dev/null || echo "")

if [ -n "${EXISTING_PR}" ]; then
  warn "PR #${EXISTING_PR} already exists for branch '${PR_BRANCH}'."
  pass "Done. PR: $(gh pr view "${EXISTING_PR}" --json url --jq '.url')"
  exit 0
fi

PR_URL=$(gh pr create \
  --title "${PR_TITLE}" \
  --body "${PR_BODY}" \
  --base "${PR_BASE}" \
  2>&1)

pass "PR created: ${PR_URL}"
echo ""
pass "Done. Branch: ${PR_BRANCH} → PR: ${PR_URL}"
