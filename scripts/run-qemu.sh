#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
DISK_PATH=${OPENCREAM_DISK:-"$PROJECT_DIR/build/creamos-debian.qcow2"}
BOOT_ISO=${OPENCREAM_BOOT_ISO:-}
MEMORY=${OPENCREAM_MEMORY:-2048}
DISK_PATH_QEMU=$(printf '%s' "$DISK_PATH" | sed 's/,/\\,/g')

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    printf '%s\n' "Error: qemu-system-x86_64 is required. Install QEMU first." >&2
    exit 1
fi

if [ ! -f "$DISK_PATH" ]; then
    printf 'Error: virtual disk not found: %s\nRun scripts/create-disk.sh first.\n' "$DISK_PATH" >&2
    exit 1
fi

set -- qemu-system-x86_64 \
    -m "$MEMORY" \
    -smp 2 \
    -accel tcg,thread=multi \
    -vga std \
    -nic user,model=virtio-net-pci \
    -drive "file=$DISK_PATH_QEMU,format=qcow2,if=virtio"

if [ -n "$BOOT_ISO" ]; then
    if [ ! -f "$BOOT_ISO" ]; then
        printf 'Error: boot ISO not found: %s\n' "$BOOT_ISO" >&2
        exit 1
    fi
    BOOT_ISO_QEMU=$(printf '%s' "$BOOT_ISO" | sed 's/,/\\,/g')
    set -- "$@" \
        -drive "file=$BOOT_ISO_QEMU,media=cdrom,readonly=on" \
        -boot order=d
else
    set -- "$@" -boot order=c
fi

if [ -n "${OPENCREAM_KERNEL:-}" ]; then
    if [ ! -f "$OPENCREAM_KERNEL" ]; then
        printf 'Error: custom kernel not found: %s\n' "$OPENCREAM_KERNEL" >&2
        exit 1
    fi
    if [ -z "${OPENCREAM_KERNEL_APPEND:-}" ]; then
        printf '%s\n' "Error: set OPENCREAM_KERNEL_APPEND when booting a custom kernel." >&2
        exit 1
    fi
    set -- "$@" -kernel "$OPENCREAM_KERNEL"
    if [ -n "${OPENCREAM_INITRD:-}" ]; then
        if [ ! -f "$OPENCREAM_INITRD" ]; then
            printf 'Error: custom initrd not found: %s\n' "$OPENCREAM_INITRD" >&2
            exit 1
        fi
        set -- "$@" -initrd "$OPENCREAM_INITRD"
    fi
    set -- "$@" -append "$OPENCREAM_KERNEL_APPEND"
fi

exec "$@"
