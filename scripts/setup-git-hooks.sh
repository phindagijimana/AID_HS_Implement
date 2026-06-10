#!/usr/bin/env bash
# Install repo git hooks (run once after clone).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_SRC="${ROOT}/.githooks/commit-msg"
HOOK_DST="${ROOT}/.git/hooks/commit-msg"

mkdir -p "${ROOT}/.git/hooks"
cp "${HOOK_SRC}" "${HOOK_DST}"
chmod +x "${HOOK_DST}" "${HOOK_SRC}"
echo "Installed ${HOOK_DST}"
