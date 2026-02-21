#!/usr/bin/env bash
# Ensures vendor/bun is populated for the given platform so electron-builder
# can include the Bun binary. Used by electron:dist:mac (and optionally
# electron:dist:linux) so that "bun run electron:dist:mac" works without
# running the full build-dmg.sh / build-linux.sh.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ELECTRON_DIR="$(dirname "$SCRIPT_DIR")"
BUN_VERSION="bun-v1.3.5"

usage() {
  echo "Usage: ensure-bun-vendor.sh --mac | --linux [arm64|x64]"
  echo "  --mac    Download Bun for darwin-arm64 and darwin-x64 to vendor/bun/darwin-{arm64,x64}/"
  echo "  --linux  Download Bun for linux (default arch: current host)"
  exit 1
}

download_darwin_arch() {
  local arch="$1"   # arm64 or x64
  local bun_name   # bun-darwin-aarch64 or bun-darwin-x64
  case "$arch" in
    arm64) bun_name="bun-darwin-aarch64" ;;
    x64)   bun_name="bun-darwin-x64" ;;
    *)     echo "Unsupported darwin arch: $arch"; exit 1 ;;
  esac

  local out_dir="$ELECTRON_DIR/vendor/bun/darwin-${arch}"
  if [ -x "$out_dir/bun" ]; then
    echo "Bun darwin-${arch} already present at $out_dir/bun, skipping download"
    return 0
  fi

  echo "Downloading Bun ${BUN_VERSION} for darwin-${arch}..."
  mkdir -p "$out_dir"
  TEMP_DIR=$(mktemp -d)
  trap "rm -rf $TEMP_DIR" EXIT

  curl -fSL "https://github.com/oven-sh/bun/releases/download/${BUN_VERSION}/${bun_name}.zip" -o "$TEMP_DIR/${bun_name}.zip"
  curl -fSL "https://github.com/oven-sh/bun/releases/download/${BUN_VERSION}/SHASUMS256.txt" -o "$TEMP_DIR/SHASUMS256.txt"
  (cd "$TEMP_DIR" && grep "${bun_name}.zip" SHASUMS256.txt | shasum -a 256 -c -)
  unzip -o "$TEMP_DIR/${bun_name}.zip" -d "$TEMP_DIR"
  cp "$TEMP_DIR/${bun_name}/bun" "$out_dir/bun"
  chmod +x "$out_dir/bun"
  echo "Installed Bun to $out_dir/bun"
}

mac() {
  download_darwin_arch arm64
  download_darwin_arch x64
}

linux() {
  local arch="${1:-$(uname -m)}"
  case "$arch" in
    aarch64|arm64) arch="arm64"; BUN_DOWNLOAD="bun-linux-aarch64" ;;
    x86_64|x64)    arch="x64";  BUN_DOWNLOAD="bun-linux-x64" ;;
    *) echo "Unsupported linux arch: $arch"; exit 1 ;;
  esac

  local out_dir="$ELECTRON_DIR/vendor/bun"
  if [ -x "$out_dir/bun" ]; then
    echo "Bun linux already present at $out_dir/bun, skipping download"
    return 0
  fi

  echo "Downloading Bun ${BUN_VERSION} for linux-${arch}..."
  mkdir -p "$out_dir"
  TEMP_DIR=$(mktemp -d)
  trap "rm -rf $TEMP_DIR" EXIT

  curl -fSL "https://github.com/oven-sh/bun/releases/download/${BUN_VERSION}/${BUN_DOWNLOAD}.zip" -o "$TEMP_DIR/${BUN_DOWNLOAD}.zip"
  curl -fSL "https://github.com/oven-sh/bun/releases/download/${BUN_VERSION}/SHASUMS256.txt" -o "$TEMP_DIR/SHASUMS256.txt"
  (cd "$TEMP_DIR" && grep "${BUN_DOWNLOAD}.zip" SHASUMS256.txt | shasum -a 256 -c -)
  unzip -o "$TEMP_DIR/${BUN_DOWNLOAD}.zip" -d "$TEMP_DIR"
  cp "$TEMP_DIR/${BUN_DOWNLOAD}/bun" "$out_dir/bun"
  chmod +x "$out_dir/bun"
  echo "Installed Bun to $out_dir/bun"
}

case "${1:-}" in
  --mac)   mac ;;
  --linux) linux "${2:-}" ;;
  *)       usage ;;
esac
