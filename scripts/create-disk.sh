#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
DISK_PATH=${1:-"$PROJECT_DIR/build/creamos-debian.qcow2"}

if ! command -v qemu-img >/dev/null 2>&1; then
    printf '%s\n' "Error: qemu-img is required. Install QEMU first." >&2
    exit 1
fi

if [ -e "$DISK_PATH" ]; then
    printf 'Error: refusing to overwrite existing disk: %s\n' "$DISK_PATH" >&2
    exit 1
fi

mkdir -p "$(dirname -- "$DISK_PATH")"
qemu-img create -f qcow2 "$DISK_PATH" 32G
printf 'Created 32 GB virtual disk: %s\n' "$DISK_PATH"
