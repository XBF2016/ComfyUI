#!/usr/bin/env bash
set -euo pipefail

# Update ComfyUI upstream into src/ using git subtree.
# Usage:
#   tools/update_upstream.sh <upstream-ref>
# Examples:
#   tools/update_upstream.sh v0.3.52
#   tools/update_upstream.sh main
#   REMOTE=myupstream PREFIX=src tools/update_upstream.sh v0.3.52
#
# Env:
#   REMOTE: git remote name for upstream (default: upstream)
#   PREFIX: subtree prefix directory (default: src)

REMOTE="${REMOTE:-upstream}"
PREFIX="${PREFIX:-src}"
REV="${1:-}"

if [[ -z "${REV}" ]]; then
  echo "Usage: $0 <upstream-ref>  (e.g., v0.3.52 or main)" >&2
  exit 1
fi

# Ensure we are at repo root (script assumes it is run from repo root)
if [[ ! -d .git ]]; then
  echo "[ERR] Not in git repository root (missing .git)" >&2
  exit 1
fi

# Check remote exists
if ! git remote get-url "${REMOTE}" >/dev/null 2>&1; then
  echo "[ERR] Remote '${REMOTE}' not found. Add it first, e.g.:" >&2
  echo "      git remote add ${REMOTE} https://github.com/comfyanonymous/ComfyUI.git" >&2
  exit 1
fi

# Fetch
echo "[INFO] Fetching from ${REMOTE} (including tags) ..."
git fetch "${REMOTE}" --tags

# Pull subtree
echo "[INFO] Pulling subtree: ${REMOTE}/${REV} -> ${PREFIX} (squash) ..."

git subtree pull \
  --prefix="${PREFIX}" \
  "${REMOTE}" "${REV}" \
  --squash \
  -m "subtree: update ComfyUI to ${REV}"

echo "[OK] Subtree updated to ${REMOTE}/${REV} under ${PREFIX}"
