#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEBIAN_VERSION=13.7.0
DEBIAN_ISO_NAME="debian-live-$DEBIAN_VERSION-amd64-xfce.iso"
DEBIAN_ISO=${DEBIAN_ISO:-"$PROJECT_DIR/build/$DEBIAN_ISO_NAME"}
DEBIAN_ISO_URL=${DEBIAN_ISO_URL:-"https://mirrors.tuna.tsinghua.edu.cn/debian-cd/current-live/amd64/iso-hybrid/$DEBIAN_ISO_NAME"}
DEBIAN_ISO_SHA256=379fcf159fa72a2ed8e3b74f4047df6061bc65adf5217e3d194e41a26fdb85e4
INSTALLER_ISO=${OPENCREAM_INSTALLER_ISO:-"$PROJECT_DIR/build/CreamOS_installer.iso"}
DISK_PATH=${OPENCREAM_DISK:-"$PROJECT_DIR/build/creamos-debian.qcow2"}
BUILD_DIR=
case "${OPENCREAM_LANGUAGE:-${LANG:-}}" in
    zh_CN*|zh_SG*|zh) UI_LANGUAGE=zh ;;
    *) UI_LANGUAGE=en ;;
esac

message() {
    if [ "$UI_LANGUAGE" = zh ]; then
        printf '%s\n' "$2"
    else
        printf '%s\n' "$1"
    fi
}

cleanup() {
    if [ -n "$BUILD_DIR" ] && [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

BREW=$(command -v brew || true)
if [ -z "$BREW" ]; then
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$candidate" ]; then
            BREW=$candidate
            break
        fi
    done
fi
if [ -n "$BREW" ]; then
    PATH="$(dirname -- "$BREW"):$PATH"
    export PATH
fi

install_homebrew_package() {
    package=$1
    if [ -z "$BREW" ]; then
        if [ "$UI_LANGUAGE" = zh ]; then
            printf '错误：需要 %s。请先安装 Homebrew，然后运行：brew install %s\n' "$package" "$package" >&2
        else
            printf 'Error: %s is required. Install Homebrew, then run: brew install %s\n' "$package" "$package" >&2
        fi
        exit 1
    fi

    if [ "$UI_LANGUAGE" = zh ]; then
        printf '需要 %s。现在通过 Homebrew 安装？[y/N] ' "$package"
    else
        printf '%s is required. Install it with Homebrew now? [y/N] ' "$package"
    fi
    IFS= read -r answer
    case "$answer" in
        y|Y|yes|YES) "$BREW" install "$package" ;;
        *)
            if [ "$UI_LANGUAGE" = zh ]; then
                printf '请运行：brew install %s\n' "$package" >&2
            else
                printf 'Install it with: brew install %s\n' "$package" >&2
            fi
            exit 1
            ;;
    esac
}

ensure_command() {
    command_name=$1
    package_name=$2
    if ! command -v "$command_name" >/dev/null 2>&1; then
        install_homebrew_package "$package_name"
    fi
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Error: %s is still unavailable after installation.\n' "$command_name" >&2
        exit 1
    fi
}

sha256_file() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{ print $1 }'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{ print $1 }'
    else
        printf '%s\n' "Error: shasum or sha256sum is required to verify the Debian ISO." >&2
        exit 1
    fi
}

is_creamos_iso() {
    image=$1
    [ -f "$image" ] || return 1
    xorriso -indev "$image" -report_el_torito plain >/dev/null 2>&1 || return 1
    xorriso -indev "$image" -ls /live 2>/dev/null | grep -Fq cream.squashfs \
        && xorriso -indev "$image" -ls /CreamOS 2>/dev/null \
            | grep -Fq cream-desktop-v2
}

ensure_command xorriso xorriso
mkdir -p "$PROJECT_DIR/build"

if ! is_creamos_iso "$INSTALLER_ISO"; then
    ensure_command curl curl
    ensure_command mksquashfs squashfs
    ensure_command unsquashfs squashfs
    BASE_ISO=
    if [ -f "$DEBIAN_ISO" ]; then
        if [ "$(sha256_file "$DEBIAN_ISO")" != "$DEBIAN_ISO_SHA256" ]; then
            printf 'Existing Debian ISO has an unexpected checksum; preserving it: %s\n' "$DEBIAN_ISO" >&2
            DEBIAN_ISO="${DEBIAN_ISO%.iso}-verified.iso"
        else
            BASE_ISO=$DEBIAN_ISO
        fi
    fi
    if [ -z "$BASE_ISO" ] && [ -f "$INSTALLER_ISO" ] \
        && xorriso -indev "$INSTALLER_ISO" -report_el_torito plain >/dev/null 2>&1 \
        && xorriso -indev "$INSTALLER_ISO" -ls /live 2>/dev/null | grep -Fq filesystem.squashfs; then
        BASE_ISO=$INSTALLER_ISO
    fi
    if [ -z "$BASE_ISO" ]; then
        if [ "$UI_LANGUAGE" = zh ]; then
            printf '正在下载 Debian %s XFCE Live 镜像...\n' "$DEBIAN_VERSION"
        else
            printf 'Downloading Debian %s XFCE live ISO...\n' "$DEBIAN_VERSION"
        fi
        PARTIAL_ISO="$DEBIAN_ISO.part"
        if [ ! -f "$PARTIAL_ISO" ]; then
            : > "$PARTIAL_ISO"
        fi
        curl -fL --retry 3 --continue-at - "$DEBIAN_ISO_URL" -o "$PARTIAL_ISO"
        actual_sha256=$(sha256_file "$PARTIAL_ISO")
        if [ "$actual_sha256" != "$DEBIAN_ISO_SHA256" ]; then
            printf 'Error: Debian ISO checksum mismatch. Expected %s, got %s.\nPartial download preserved at %s\n' \
                "$DEBIAN_ISO_SHA256" "$actual_sha256" "$PARTIAL_ISO" >&2
            exit 1
        fi
        mv "$PARTIAL_ISO" "$DEBIAN_ISO"
        BASE_ISO=$DEBIAN_ISO
    fi

    BUILD_DIR=$(mktemp -d "$PROJECT_DIR/build/.creamos-build.XXXXXX")
    CANDIDATE_ISO="$BUILD_DIR/CreamOS_installer.iso"
    sh "$PROJECT_DIR/scripts/build-installer-iso.sh" "$BASE_ISO" "$CANDIDATE_ISO"
    mv -f "$CANDIDATE_ISO" "$INSTALLER_ISO"
    rmdir "$BUILD_DIR"
    BUILD_DIR=
fi

if [ "$UI_LANGUAGE" = zh ]; then
    printf '\nCreamOS Debian XFCE 安装镜像已就绪：\n%s\n\n' "$INSTALLER_ISO"
    printf '%s\n' \
        "1) 在 QEMU 中启动 CreamOS 桌面" \
        "2) 在 Finder 中显示镜像，以便在 UTM 中使用" \
        "3) 启动已安装的 CreamOS 虚拟磁盘" \
        "4) 退出"
    printf '请选择 [1-4]：'
else
    printf '\nCreamOS Debian XFCE installer ISO is ready:\n%s\n\n' "$INSTALLER_ISO"
    printf '%s\n' \
        "1) Start the CreamOS live desktop in QEMU" \
        "2) Show the ISO in Finder for use with UTM" \
        "3) Boot the installed CreamOS virtual disk" \
        "4) Exit"
    printf 'Choose [1-4]: '
fi
IFS= read -r choice

case "$choice" in
    1)
        ensure_command qemu-system-x86_64 qemu
        ensure_command qemu-img qemu
        if [ ! -f "$DISK_PATH" ]; then
            OPENCREAM_DISK="$DISK_PATH" sh "$PROJECT_DIR/scripts/create-disk.sh"
        fi
        if [ "$UI_LANGUAGE" = zh ]; then
            printf '\n请启动 CreamOS 桌面，然后双击“安装 CreamOS”将系统安装到虚拟磁盘。\n'
        else
            printf '\nStart the CreamOS live desktop, then double-click “Install CreamOS” to install it to the virtual disk.\n'
        fi
        OPENCREAM_MEMORY=${OPENCREAM_MEMORY:-2048} \
            OPENCREAM_DISK="$DISK_PATH" OPENCREAM_BOOT_ISO="$INSTALLER_ISO" \
            sh "$PROJECT_DIR/scripts/run-qemu.sh"
        ;;
    2)
        open -R "$INSTALLER_ISO"
        if [ "$UI_LANGUAGE" = zh ]; then
            printf '%s\n' \
                "在 UTM 中创建 x86_64 虚拟机（至少 2 GiB 内存），" \
                "将此 ISO 设为启动镜像，并创建 32 GiB 虚拟磁盘。"
        else
            printf '%s\n' \
                "In UTM, create an x86_64 virtual machine with at least 2 GiB RAM," \
                "attach this ISO as the boot image, and create a 32 GiB virtual disk."
        fi
        ;;
    3)
        ensure_command qemu-system-x86_64 qemu
        if [ ! -f "$DISK_PATH" ]; then
            if [ "$UI_LANGUAGE" = zh ]; then
                printf '错误：找不到虚拟磁盘：%s\n请先启动 Live 桌面创建磁盘并安装 CreamOS。\n' "$DISK_PATH" >&2
            else
                printf 'Error: virtual disk not found: %s\nStart the live desktop first to create it and install CreamOS.\n' "$DISK_PATH" >&2
            fi
            exit 1
        fi
        OPENCREAM_DISK="$DISK_PATH" sh "$PROJECT_DIR/scripts/run-qemu.sh"
        ;;
    4) exit 0 ;;
    *)
        printf '%s\n' "No valid option selected." >&2
        exit 2
        ;;
esac
