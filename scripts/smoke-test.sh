#!/usr/bin/env bash
set -euo pipefail

# smoke-test.sh — Run smoke tests against the running Resource Plane stack.
# Called by `make test-smoke` or directly.
# Exits non-zero if any check fails.



RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { printf "%b\n" "${GREEN}✅ ${*}${NC}"; }
fail() { printf "%b\n" "${RED}❌ ${*}${NC}"; }

FAILURES=0
check() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass "${description}"
  else
    fail "${description}"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "=== Resource Plane Smoke Tests ==="
echo ""

# ── 1) PostgreSQL — list databases ────────────────────────────────────────────
check "PostgreSQL: database listing" \
  docker exec fawkes-postgres psql -U fawkes_admin -c "\\l"

# ── 2) Valkey — PING ──────────────────────────────────────────────────────────
check "Valkey: PING → PONG" \
  sh -c 'docker exec fawkes-cache valkey-cli PING | grep -q PONG'

# ── 3) Traefik — health endpoint ──────────────────────────────────────────────
check "Traefik: /ping responds 200" \
  curl -sf http://localhost:80/ping

# ── 4) Authelia — health endpoint ─────────────────────────────────────────────
check "Authelia: /api/health responds 200" \
  curl -sf http://localhost:9091/api/health

echo ""
if [ "${FAILURES}" -eq 0 ]; then
  echo "========================================"
  pass "All smoke tests passed"
  echo "========================================"
  exit 0
else
  echo "========================================"
  fail "${FAILURES} smoke test(s) failed"
  echo "========================================"
  exit 1
fi
