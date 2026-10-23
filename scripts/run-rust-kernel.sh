#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
KERNEL_DIR="$PROJECT_DIR/rust-kernel"

if ! command -v cargo >/dev/null 2>&1; then
    printf '%s\n' "Error: Rust nightly is required. Install rustup, then run: rustup toolchain install nightly" >&2
    exit 1
fi

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    printf '%s\n' "Error: qemu-system-x86_64 is required. Install QEMU first." >&2
    exit 1
fi

cd "$KERNEL_DIR"
exec cargo run --release
