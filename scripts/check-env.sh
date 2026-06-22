#!/usr/bin/env bash
set -euo pipefail

# check-env.sh — Validate required environment variables for the Resource Plane.
# Called by `make up` before starting the stack.
#
# Exits 1 if any required variable is unset, empty, or set to "changeme".

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

RED='\033[0;31m'
NC='\033[0m'

fail() {
  printf "%b\n" "${RED}❌ ${*}${NC}" >&2
  exit 1
}

# ── 1) Source .env if it exists ───────────────────────────────────────────────

if [ -f "${ENV_FILE}" ]; then
  set -a
  # shellcheck source=/dev/null
  . "${ENV_FILE}"
  set +a
fi

# ── 2) Validate each required variable ────────────────────────────────────────

check_var() {
  local var_name="$1"
  local var_value="${!var_name:-}"

  if [ -z "${var_value}" ]; then
    fail "${var_name} is not set. Add it to .env or export it before running."
  fi

  if [ "${var_value}" = "changeme" ]; then
    fail "${var_name} is still set to the default value 'changeme'. Set a real value in .env"
  fi
}

check_var "SHARED_DB_PASSWORD"
check_var "AUTHELIA_JWT_SECRET"
check_var "AUTHELIA_SESSION_SECRET"

echo "✅ Environment check passed — all required variables are set."
