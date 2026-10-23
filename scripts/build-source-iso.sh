#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
ISO_PATH=${1:-"$PROJECT_DIR/build/opencream-source.iso"}

if ! command -v xorriso >/dev/null 2>&1; then
    printf '%s\n' "Error: xorriso is required to build the source ISO." >&2
    exit 1
fi

mkdir -p "$(dirname -- "$ISO_PATH")"
xorriso -as mkisofs -quiet -R -J -V OPENCREAM_SRC \
    -o "$ISO_PATH" \
    -graft-points \
    "README.md=$PROJECT_DIR/README.md" \
    "assets=$PROJECT_DIR/assets" \
    "scripts/install-opencream.sh=$PROJECT_DIR/scripts/install-opencream.sh"

printf 'Created source ISO: %s\n' "$ISO_PATH"
