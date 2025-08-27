#!/usr/bin/env bash
set -euo pipefail

# Wrapper: Start ComfyUI WITHOUT proxy (force direct connection)
# Usage examples:
#   ./comfyui_noproxy.sh start --host 127.0.0.1 --port 8188
#   ./comfyui_noproxy.sh restart

# Resolve repo root based on this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}"

# Force disable proxy for this run
PROXY_URL=""      # empty => comfyui.sh will inject empty HTTP(S)_PROXY vars
NO_PROXY="*"      # bypass proxy for all hosts

# Delegate to main script with env variables that disable proxy
exec env \
  PROXY_URL="${PROXY_URL}" \
  NO_PROXY="${NO_PROXY}" \
  "${ROOT}/comfyui.sh" "$@"
