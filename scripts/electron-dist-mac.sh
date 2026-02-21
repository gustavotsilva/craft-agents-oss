#!/usr/bin/env bash
# Wrapper for electron:dist:mac that loads .env from repo root so you can run
#   bun run electron:dist:mac
# without manually sourcing .env (e.g. for CSC_LINK, CSC_NAME, APPLE_*).
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

bun run electron:build
bash apps/electron/scripts/ensure-bun-vendor.sh --mac
exec electron-builder --config electron-builder.yml --project apps/electron --mac
