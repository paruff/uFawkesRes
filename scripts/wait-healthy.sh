#!/usr/bin/env bash
set -euo pipefail

# wait-healthy.sh — Poll health endpoints until all services are ready.
# Called after `make up` to wait for the stack to become healthy.
#
# Environment variables:
#   WAIT_TIMEOUT   — total seconds to wait (default: 60)
#   WAIT_INTERVAL  — seconds between retries (default: 3)

WAIT_TIMEOUT="${WAIT_TIMEOUT:-60}"
WAIT_INTERVAL="${WAIT_INTERVAL:-3}"
CURL_CONNECT_TIMEOUT="${CURL_CONNECT_TIMEOUT:-5}"
CURL_MAX_TIME="${CURL_MAX_TIME:-10}"

readonly WAIT_TIMEOUT WAIT_INTERVAL CURL_CONNECT_TIMEOUT CURL_MAX_TIME

validate_positive_integer() {
  local value="$1"
  local variable_name="$2"

  if ! [[ "${value}" =~ ^[0-9]+$ ]] || (( value <= 0 )); then
    echo "❌ ${variable_name} must be a positive integer (seconds), got: ${value}"
    exit 1
  fi
}

SERVICES=(
  "Traefik|http://localhost:80/ping"
  "Authelia|http://localhost:9091/api/health"
)
readonly SERVICES

# Require Bash 4+ for associative arrays
if (( BASH_VERSINFO[0] < 4 )); then
  echo "❌ scripts/wait-healthy.sh requires Bash 4+."
  echo "On macOS, install a newer Bash (e.g., 'brew install bash') and run '/opt/homebrew/bin/bash ./scripts/wait-healthy.sh'."
  exit 1
fi

declare -A SERVICE_READY=()

is_service_ready() {
  local url="$1"
  curl -fsS --connect-timeout "${CURL_CONNECT_TIMEOUT}" --max-time "${CURL_MAX_TIME}" "${url}" >/dev/null 2>&1
}

main() {
  local start_time deadline now elapsed
  local all_ready
  local service name url service_now_ready

  validate_positive_integer "${WAIT_TIMEOUT}" "WAIT_TIMEOUT"
  validate_positive_integer "${WAIT_INTERVAL}" "WAIT_INTERVAL"

  start_time=$(date +%s)
  deadline=$((start_time + WAIT_TIMEOUT))
  echo "Waiting for resource plane services (timeout: ${WAIT_TIMEOUT}s)"

  while true; do
    all_ready=true

    for service in "${SERVICES[@]}"; do
      name="${service%%|*}"
      url="${service#*|}"

      if [[ "${SERVICE_READY[$name]:-false}" == "true" ]]; then
        continue
      fi

      service_now_ready=false
      if is_service_ready "${url}"; then
        SERVICE_READY["$name"]=true
        service_now_ready=true
      else
        all_ready=false
      fi

      now=$(date +%s)
      elapsed=$((now - start_time))

      if [[ "${service_now_ready}" == "true" ]]; then
        echo "✅ ${name} healthy (${elapsed}s)"
      fi

      if (( now >= deadline )); then
        all_ready=false
        break
      fi
    done

    now=$(date +%s)
    elapsed=$((now - start_time))

    if [[ "${all_ready}" == "true" ]]; then
      echo "========================================"
      echo "✅ All services are healthy (${elapsed}s)"
      echo "========================================"
      exit 0
    fi

    if (( now >= deadline )); then
      echo "========================================"
      for service in "${SERVICES[@]}"; do
        name="${service%%|*}"
        if [[ "${SERVICE_READY[$name]:-false}" != "true" ]]; then
          echo "❌ ${name} not healthy (${elapsed}s)"
        fi
      done
      echo "❌ Timeout waiting for services after ${WAIT_TIMEOUT}s"
      echo "========================================"
      exit 1
    fi

    sleep "${WAIT_INTERVAL}"
  done
}

main "$@"
