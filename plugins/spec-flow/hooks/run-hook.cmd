#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_NAME="${1:?Usage: run-hook.cmd <hook-name>}"
exec "${SCRIPT_DIR}/${HOOK_NAME}"
