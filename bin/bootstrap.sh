#!/usr/bin/env bash
set -euo pipefail

# Selector for bootstrapping either a frontend (TS/React) or python project.

TYPE="${TYPE:-}"
PM="${PM:-}"
SELF_DESTRUCT="${SELF_DESTRUCT:-0}"

usage() {
  cat <<USAGE
Usage: bootstrap.sh --type <frontend|python|rust> [--pm bun|pnpm|yarn]

Env:
  TYPE=frontend|python|rust  PM=bun|pnpm|yarn  SELF_DESTRUCT=0|1
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --type) TYPE="$2"; shift 2;;
    --pm) PM="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 2;;
  esac
done

if [ -z "$TYPE" ]; then
  echo "[bootstrap] Missing --type. Use frontend, python, or rust." >&2
  usage; exit 2
fi

case "$TYPE" in
  frontend)
    exec bash "$(dirname "$0")/bootstrap-frontend.sh"
    ;;
  python)
    exec bash "$(dirname "$0")/bootstrap-python.sh"
    ;;
  rust)
    exec bash "$(dirname "$0")/bootstrap-rust.sh"
    ;;
  *)
    echo "[bootstrap] Unknown type: $TYPE" >&2
    usage; exit 2
    ;;
esac
