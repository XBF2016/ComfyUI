#!/usr/bin/env bash
set -euo pipefail

# Wrapper: Start ComfyUI WITH proxy (scoped to this process tree only)
# Usage examples:
#   ./comfyui_proxy.sh start --host 0.0.0.0 --port 8188
#   ./comfyui_proxy.sh restart -- --help

# Resolve repo root based on this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}"

# Proxy config (can be overridden by environment before calling this script)
: "${PROXY_URL:=http://172.16.104.138:33210}"
: "${NO_PROXY:=localhost,127.0.0.1,::1}"

# Delegate to main script with env variables
exec env \
  PROXY_URL="${PROXY_URL}" \
  NO_PROXY="${NO_PROXY}" \
  "${ROOT}/comfyui.sh" "$@"
