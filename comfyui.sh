#!/usr/bin/env bash
set -euo pipefail

# ComfyUI manager script (user-level, no system config changes)
# Usage examples:
#   ./comfyui.sh start --host 0.0.0.0 --port 8188 --multi-user
#   ./comfyui.sh stop
#   ./comfyui.sh restart --host 127.0.0.1 --port 8288
#   ./comfyui.sh status
#   ./comfyui.sh start -- --extra-comfy-arg value   # pass through unknown args

ROOT="${HOME}/ComfyUI"
PY="${ROOT}/.venv/bin/python"
MAIN="${ROOT}/src/main.py"
PIDFILE="${ROOT}/comfyui.pid"
LOGFILE="${ROOT}/comfyui.out"

# Defaults (can be overridden by flags)
HOST="0.0.0.0"
PORT="8188"
EXTRA_ARGS=""

# Scoped proxy (only for ComfyUI process tree)
# You can override via environment before calling this script: PROXY_URL, NO_PROXY
PROXY_URL="${PROXY_URL-http://172.16.104.138:33210}"
NO_PROXY="${NO_PROXY-localhost,127.0.0.1,::1}"

usage() {
  cat <<EOF
ComfyUI service manager

Commands:
  start     Start ComfyUI in background (nohup)
  stop      Stop running ComfyUI process
  restart   Restart ComfyUI (stop then start)
  status    Show running status

Options (for start/restart):
  --host, -H   Listen host (default: ${HOST})
  --port, -P   Port (default: ${PORT})
  --multi-user Enable multi-user mode
  --           Pass any remaining args directly to ComfyUI

Examples:
  ${0} start --host 0.0.0.0 --port 8188 --multi-user
  ${0} restart -H 127.0.0.1 -P 8288
  ${0} start -- --help  # show ComfyUI own help
EOF
}

ensure_paths() {
  if [[ ! -x "${PY}" ]]; then
    echo "[ERR] Python venv not found at ${PY}. Create it first: python3 -m venv ${ROOT}/.venv" >&2
    exit 1
  fi
  if [[ ! -f "${MAIN}" ]]; then
    echo "[ERR] ComfyUI main not found at ${MAIN}. Clone repo into ${ROOT}/src" >&2
    exit 1
  fi
}

is_running() {
  if [[ -f "${PIDFILE}" ]]; then
    local pid
    pid=$(cat "${PIDFILE}" 2>/dev/null || true)
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "$pid"
      return 0
    fi
  fi
  return 1
}

parse_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host|-H)
        HOST="${2:-}"
        shift 2
        ;;
      --port|-P)
        PORT="${2:-}"
        shift 2
        ;;
      --multi-user)
        EXTRA_ARGS+=" --multi-user"
        shift 1
        ;;
      --)
        shift
        # pass through the rest
        if [[ $# -gt 0 ]]; then
          EXTRA_ARGS+=" $(printf '%q ' "$@")"
          shift $(($#)) || true
        fi
        ;;
      -h|--help)
        usage; exit 0
        ;;
      *)
        # unknown option -> pass through
        EXTRA_ARGS+=" $(printf '%q' "$1")"
        shift 1
        ;;
    esac
  done
}

cmd_start() {
  ensure_paths
  if pid=$(is_running); then
    echo "[OK] Already running: PID=${pid} (see ${LOGFILE})"
    exit 0
  fi
  echo "[INFO] Starting ComfyUI on ${HOST}:${PORT} ..."
  # Inject HTTP/HTTPS proxy only for this process and its children
  nohup env \
    PATH="${ROOT}/.venv/bin:${PATH}" \
    HTTP_PROXY="${PROXY_URL}" \
    HTTPS_PROXY="${PROXY_URL}" \
    http_proxy="${PROXY_URL}" \
    https_proxy="${PROXY_URL}" \
    NO_PROXY="${NO_PROXY}" \
    no_proxy="${NO_PROXY}" \
    "${PY}" "${MAIN}" --listen "${HOST}" --port "${PORT}" ${EXTRA_ARGS} >"${LOGFILE}" 2>&1 &
  echo $! > "${PIDFILE}"
  sleep 2
  if pid=$(is_running); then
    echo "[OK] Started PID=${pid}. Log: ${LOGFILE}"
    echo "Open: http://${HOST}:${PORT}" || true
  else
    echo "[ERR] Failed to start. See log: ${LOGFILE}" >&2
    exit 1
  fi
}

cmd_stop() {
  if pid=$(is_running); then
    echo "[INFO] Stopping PID=${pid} ..."
    kill -TERM "$pid" 2>/dev/null || true
    # wait up to 10s
    for i in {1..10}; do
      if ! kill -0 "$pid" 2>/dev/null; then
        break
      fi
      sleep 1
    done
    if kill -0 "$pid" 2>/dev/null; then
      echo "[WARN] Force killing PID=${pid}"
      kill -KILL "$pid" 2>/dev/null || true
    fi
    rm -f "${PIDFILE}"
    echo "[OK] Stopped"
  else
    echo "[INFO] Not running"
  fi
}

cmd_status() {
  if pid=$(is_running); then
    echo "[OK] Running PID=${pid}"
    echo "Log: ${LOGFILE}"
    echo "PID file: ${PIDFILE}"
  else
    echo "[INFO] Not running"
  fi
}

cmd_restart() {
  cmd_stop || true
  cmd_start
}

main() {
  local cmd="${1:-}"
  if [[ -z "${cmd}" ]]; then
    usage; exit 1
  fi
  shift || true

  case "${cmd}" in
    start)
      parse_flags "$@"
      cmd_start
      ;;
    stop)
      cmd_stop
      ;;
    restart)
      parse_flags "$@"
      cmd_restart
      ;;
    status)
      cmd_status
      ;;
    *)
      usage; exit 1
      ;;
  esac
}

main "$@"
