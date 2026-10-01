#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$PROJECT_DIR/LGTVScratch"
DEVICE_NAME="${1:-HomeLGTV}"
PACKAGE_DIR="${LGTV_PACKAGE_DIR:-/private/tmp}"

for tool in node ares-package ares-install ares-launch; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Missing required tool: %s\n' "$tool" >&2
    exit 1
  fi
done

APP_ID="$(node -e 'process.stdout.write(require(process.argv[1]).id)' "$APP_DIR/appinfo.json")"
APP_VERSION="$(node -e 'process.stdout.write(require(process.argv[1]).version)' "$APP_DIR/appinfo.json")"
PACKAGE_PATH="$PACKAGE_DIR/${APP_ID}_${APP_VERSION}_all.ipk"

mkdir -p "$PACKAGE_DIR"
printf 'Packaging %s %s...\n' "$APP_ID" "$APP_VERSION"
ares-package --outdir "$PACKAGE_DIR" "$APP_DIR"

if [[ ! -f "$PACKAGE_PATH" ]]; then
  printf 'Package was not created: %s\n' "$PACKAGE_PATH" >&2
  exit 1
fi

printf 'Installing on %s...\n' "$DEVICE_NAME"
ares-launch --device "$DEVICE_NAME" --close "$APP_ID" >/dev/null 2>&1 || true
ares-install --device "$DEVICE_NAME" "$PACKAGE_PATH"

printf 'Launching on %s...\n' "$DEVICE_NAME"
ares-launch --device "$DEVICE_NAME" "$APP_ID"
printf 'Done. Package: %s\n' "$PACKAGE_PATH"
