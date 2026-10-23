#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BASE_ISO=${1:-${DEBIAN_ISO:-}}
OUTPUT_ISO=${2:-${OPENCREAM_INSTALLER_ISO:-"$PROJECT_DIR/build/CreamOS_installer.iso"}}
TEMP_DIR=

cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

for command_name in xorriso mksquashfs unsquashfs; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Error: %s is required to build the CreamOS ISO.\n' "$command_name" >&2
        exit 1
    fi
done
for command_name in curl tar unzip; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Error: %s is required to bundle MiSans and Google Chrome.\n' "$command_name" >&2
        exit 1
    fi
done

if [ -z "$BASE_ISO" ] || [ ! -f "$BASE_ISO" ]; then
    printf '%s\n' "Usage: build-installer-iso.sh LIVE_XFCE_ISO [OUTPUT_ISO]" >&2
    exit 2
fi
if ! xorriso -indev "$BASE_ISO" -report_el_torito plain >/dev/null 2>&1; then
    printf 'Error: Live ISO is incomplete or not bootable: %s\n' "$BASE_ISO" >&2
    exit 1
fi
if [ "$BASE_ISO" -ef "$OUTPUT_ISO" ]; then
    printf '%s\n' "Error: input and output ISO paths must be different." >&2
    exit 1
fi
if [ -e "$OUTPUT_ISO" ]; then
    printf 'Error: refusing to overwrite existing ISO: %s\n' "$OUTPUT_ISO" >&2
    exit 1
fi
if [ ! -f "$PROJECT_DIR/assets/gtk/Material3/gtk-3.0/gtk.css" ] \
    || [ ! -f "$PROJECT_DIR/assets/gtk/LiquidGlass/gtk-3.0/gtk.css" ] \
    || [ ! -f "$PROJECT_DIR/assets/gtk/Texture/gtk-3.0/gtk.css" ] \
    || [ ! -f "$PROJECT_DIR/vendor/fonts/MiSans-Regular.ttf" ] \
    || [ ! -f "$PROJECT_DIR/vendor/fonts/MiSansLatin-Regular.ttf" ] \
    || [ ! -f "$PROJECT_DIR/assets/installer/build-id" ] \
    || [ ! -f "$PROJECT_DIR/assets/installer/cream-installer" ] \
    || [ ! -f "$PROJECT_DIR/assets/installer/cream-desktop-icon" ] \
    || [ ! -f "$PROJECT_DIR/assets/installer/cream-session-branding" ] \
    || [ ! -f "$PROJECT_DIR/assets/installer/cream-session-branding.desktop" ] \
    || [ ! -f "$PROJECT_DIR/assets/installer/creamos-splash.png" ] \
    || [ ! -f "$PROJECT_DIR/scripts/install-opencream.sh" ]; then
    printf 'Error: CreamOS sources not found under %s.\n' "$PROJECT_DIR" >&2
    exit 1
fi

if ! xorriso -indev "$BASE_ISO" -ls /live 2>/dev/null | grep -Fq filesystem.squashfs; then
    printf 'Error: no Live filesystem.squashfs found in %s\n' "$BASE_ISO" >&2
    exit 1
fi

TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/creamos-installer.XXXXXX")
if [ -n "${XDG_CACHE_HOME:-}" ]; then
    CACHE_DIR="$XDG_CACHE_HOME/creamos"
elif [ "$(uname -s)" = Darwin ]; then
    CACHE_DIR="$HOME/Library/Caches/CreamOS"
else
    CACHE_DIR="$HOME/.cache/creamos"
fi
mkdir -p "$CACHE_DIR"
CHROME_DEB="$CACHE_DIR/google-chrome-stable_current_amd64.deb"

if [ ! -f "$CHROME_DEB" ]; then
    curl -fL --retry 3 \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        -o "$CHROME_DEB.part"
    mv "$CHROME_DEB.part" "$CHROME_DEB"
fi
if ! tar -tf "$CHROME_DEB" | grep -Fq data.tar.xz; then
    printf '%s\n' "Error: Google Chrome download is invalid; clear the cached file and retry." >&2
    exit 1
fi

OVERLAY_ROOT="$TEMP_DIR/overlay"
OVERLAY_IMAGE="$TEMP_DIR/cream.squashfs"
BASE_SQUASHFS="$TEMP_DIR/filesystem.squashfs"
CHROME_ROOT="$TEMP_DIR/chrome"
mkdir -p \
    "$OVERLAY_ROOT/etc/calamares/branding/creamos" \
    "$OVERLAY_ROOT/etc/calamares/modules" \
    "$OVERLAY_ROOT/etc/skel/.config/gtk-3.0" \
    "$OVERLAY_ROOT/etc/xdg/autostart" \
    "$OVERLAY_ROOT/etc/xdg/xfce4/xfconf/xfce-perchannel-xml" \
    "$OVERLAY_ROOT/usr/bin" \
    "$OVERLAY_ROOT/usr/local/bin" \
    "$OVERLAY_ROOT/usr/local/share/creamos" \
    "$OVERLAY_ROOT/usr/share/applications" \
    "$OVERLAY_ROOT/usr/share/backgrounds/creamos" \
    "$OVERLAY_ROOT/usr/share/doc/fonts-misans" \
    "$OVERLAY_ROOT/usr/share/icons/hicolor/scalable/apps" \
    "$OVERLAY_ROOT/usr/share/themes/Material3/gtk-3.0" \
    "$OVERLAY_ROOT/usr/share/themes/LiquidGlass/gtk-3.0" \
    "$OVERLAY_ROOT/usr/share/themes/Texture/gtk-3.0" \
    "$OVERLAY_ROOT/usr/share/fonts/truetype/misans" \
    "$CHROME_ROOT"

xorriso -osirrox on -indev "$BASE_ISO" \
    -extract /live/filesystem.squashfs "$BASE_SQUASHFS"

unsquashfs -cat "$BASE_SQUASHFS" etc/calamares/settings.conf \
    > "$TEMP_DIR/calamares-settings.conf"
if ! grep -Fq 'branding: debian' "$TEMP_DIR/calamares-settings.conf"; then
    printf '%s\n' "Error: Debian Calamares branding configuration was not found." >&2
    exit 1
fi
sed 's/^branding: debian$/branding: creamos/' "$TEMP_DIR/calamares-settings.conf" \
    > "$OVERLAY_ROOT/etc/calamares/settings.conf"
if ! grep -Fq 'branding: creamos' "$OVERLAY_ROOT/etc/calamares/settings.conf"; then
    printf '%s\n' "Error: failed to set CreamOS Calamares branding." >&2
    exit 1
fi

unsquashfs -cat "$BASE_SQUASHFS" etc/calamares/modules/unpackfs.conf \
    > "$TEMP_DIR/unpackfs.conf"
awk '
    { print }
    /^[[:space:]]*destination:[[:space:]]*""[[:space:]]*$/ && !inserted {
        print "    -   source: \"/run/live/medium/live/cream.squashfs\""
        print "        sourcefs: \"squashfs\""
        print "        destination: \"\""
        inserted = 1
    }
    END { if (!inserted) exit 1 }
' "$TEMP_DIR/unpackfs.conf" > "$OVERLAY_ROOT/etc/calamares/modules/unpackfs.conf"

cat > "$TEMP_DIR/filesystem.module" <<'EOF'
filesystem.squashfs
cream.squashfs
EOF

cp -R "$PROJECT_DIR/assets" "$PROJECT_DIR/scripts" "$PROJECT_DIR/vendor" "$PROJECT_DIR/README.md" \
    "$OVERLAY_ROOT/usr/local/share/creamos/"
install -m 0644 "$PROJECT_DIR/assets/installer/build-id" \
    "$OVERLAY_ROOT/usr/local/share/creamos/build-id"
install -m 0755 "$PROJECT_DIR/assets/installer/cream-installer" \
    "$OVERLAY_ROOT/usr/local/bin/cream-installer"
install -m 0755 "$PROJECT_DIR/assets/installer/cream-desktop-icon" \
    "$OVERLAY_ROOT/usr/bin/add-calamares-desktop-icon"
install -m 0755 "$PROJECT_DIR/assets/installer/cream-session-branding" \
    "$OVERLAY_ROOT/usr/local/bin/cream-session-branding"
install -m 0644 "$PROJECT_DIR/assets/installer/cream-session-branding.desktop" \
    "$OVERLAY_ROOT/etc/xdg/autostart/cream-session-branding.desktop"
install -m 0644 "$PROJECT_DIR/assets/installer/calamares-install-cream.desktop" \
    "$OVERLAY_ROOT/usr/share/applications/calamares-install-debian.desktop"
install -m 0644 "$PROJECT_DIR/assets/installer/creamos-logo.svg" \
    "$OVERLAY_ROOT/usr/share/icons/hicolor/scalable/apps/creamos-logo.svg"
install -m 0644 "$PROJECT_DIR/assets/installer/creamos-logo.svg" \
    "$OVERLAY_ROOT/etc/calamares/branding/creamos/creamos-logo.svg"
install -m 0644 "$PROJECT_DIR/assets/installer/creamos-welcome.svg" \
    "$OVERLAY_ROOT/etc/calamares/branding/creamos/creamos-welcome.svg"
install -m 0644 "$PROJECT_DIR/assets/installer/branding.desc" \
    "$OVERLAY_ROOT/etc/calamares/branding/creamos/branding.desc"
install -m 0644 "$PROJECT_DIR/assets/installer/creamos-wallpaper.svg" \
    "$OVERLAY_ROOT/usr/share/backgrounds/creamos/creamos-wallpaper.svg"
for theme in Material3 LiquidGlass Texture; do
    install -m 0644 "$PROJECT_DIR/assets/gtk/$theme/index.theme" \
        "$OVERLAY_ROOT/usr/share/themes/$theme/index.theme"
    install -m 0644 "$PROJECT_DIR/assets/gtk/$theme/gtk-3.0/gtk.css" \
        "$OVERLAY_ROOT/usr/share/themes/$theme/gtk-3.0/gtk.css"
done
install -m 0644 "$PROJECT_DIR/vendor/fonts/MiSans-Regular.ttf" \
    "$OVERLAY_ROOT/usr/share/fonts/truetype/misans/"
install -m 0644 "$PROJECT_DIR/vendor/fonts/MiSansLatin-Regular.ttf" \
    "$OVERLAY_ROOT/usr/share/fonts/truetype/misans/"
install -m 0644 "$PROJECT_DIR/vendor/fonts/README.md" \
    "$OVERLAY_ROOT/usr/share/doc/fonts-misans/README"

tar -xf "$CHROME_DEB" -C "$CHROME_ROOT"
CHROME_DATA="$CHROME_ROOT/data.tar.xz"
if [ ! -f "$CHROME_DATA" ]; then
    printf '%s\n' "Error: Google Chrome package has no supported data archive." >&2
    exit 1
fi
tar -xJf "$CHROME_DATA" -C "$OVERLAY_ROOT"
if [ ! -L "$OVERLAY_ROOT/usr/bin/google-chrome-stable" ] \
    || [ ! -x "$OVERLAY_ROOT/opt/google/chrome/google-chrome" ] \
    || [ ! -f "$OVERLAY_ROOT/usr/share/applications/google-chrome.desktop" ]; then
    printf '%s\n' "Error: Google Chrome package extraction did not produce its browser launcher." >&2
    exit 1
fi

cat > "$OVERLAY_ROOT/etc/locale.gen" <<'EOF'
en_US.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
EOF

cat > "$OVERLAY_ROOT/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Material3"/>
    <property name="IconThemeName" type="string" value="Tango"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="MiSans 10"/>
  </property>
</channel>
EOF
cat > "$OVERLAY_ROOT/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/creamos/creamos-wallpaper.svg"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF
cat > "$OVERLAY_ROOT/etc/skel/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Material3
gtk-font-name=MiSans 10
gtk-application-prefer-dark-theme=false
EOF

cat > "$TEMP_DIR/creamos-grub.cfg" <<'EOF'
source /boot/grub/config.cfg
set timeout=5
set default=0

menuentry "Start CreamOS XFCE (Chinese)" --hotkey=l {
    linux /live/vmlinuz boot=live components quiet hostname=creamos user-fullname=CreamOS locales=zh_CN.UTF-8 findiso=${iso_path}
    initrd /live/initrd.img
}

menuentry "Start CreamOS XFCE (English)" {
    linux /live/vmlinuz boot=live components quiet hostname=creamos user-fullname=CreamOS locales=en_US.UTF-8 findiso=${iso_path}
    initrd /live/initrd.img
}

menuentry "CreamOS XFCE (failsafe)" {
    linux /live/vmlinuz boot=live components memtest noapic noapm nodma nomce nosmp nosplash vga=788
    initrd /live/initrd.img
}

menuentry "Verify CreamOS installer media" --hotkey=v {
    linux /live/vmlinuz boot=live components findiso=${iso_path} verify-checksums
    initrd /live/initrd.img
}

if [ "${grub_platform}" = "efi" ]; then
    menuentry "UEFI Firmware Settings" --hotkey=f {
        fwsetup
    }
fi
EOF
cat > "$TEMP_DIR/creamos-isolinux.cfg" <<'EOF'
include menu.cfg
default vesamenu.c32
prompt 0
timeout 50
EOF
cat > "$TEMP_DIR/creamos-menu.cfg" <<'EOF'
menu hshift 0
menu width 82
menu title CreamOS Boot Menu
include stdmenu.cfg
include live.cfg
menu begin utilities
    menu label ^Utilities
    menu title Utilities
    include stdmenu.cfg
    label mainmenu
        menu label ^Back..
        menu exit
    include utilities.cfg
menu end
menu clear
EOF
cat > "$TEMP_DIR/creamos-live.cfg" <<'EOF'
label live-amd64
    menu label ^Start CreamOS XFCE (Chinese)
    menu default
    linux /live/vmlinuz
    initrd /live/initrd.img
    append boot=live components quiet hostname=creamos user-fullname=CreamOS locales=zh_CN.UTF-8

label live-amd64-english
    menu label Start CreamOS XFCE (English)
    linux /live/vmlinuz
    initrd /live/initrd.img
    append boot=live components quiet hostname=creamos user-fullname=CreamOS locales=en_US.UTF-8

label live-amd64-failsafe
    menu label CreamOS XFCE (failsafe)
    linux /live/vmlinuz
    initrd /live/initrd.img
    append boot=live components memtest noapic noapm nodma nomce nosmp nosplash vga=788
EOF

mksquashfs "$OVERLAY_ROOT" "$OVERLAY_IMAGE" \
    -noappend -all-root -no-xattrs -comp xz -b 131072 -no-progress
unsquashfs -s "$OVERLAY_IMAGE" >/dev/null

mkdir -p "$(dirname -- "$OUTPUT_ISO")"
xorriso \
    -indev "$BASE_ISO" \
    -outdev "$OUTPUT_ISO" \
    -volid CREAMOS_INSTALLER \
    -boot_image any replay \
    -map "$OVERLAY_IMAGE" /live/cream.squashfs \
    -map "$TEMP_DIR/filesystem.module" /live/filesystem.module \
    -map "$TEMP_DIR/creamos-grub.cfg" /boot/grub/grub.cfg \
    -map "$TEMP_DIR/creamos-isolinux.cfg" /isolinux/isolinux.cfg \
    -map "$TEMP_DIR/creamos-menu.cfg" /isolinux/menu.cfg \
    -map "$TEMP_DIR/creamos-live.cfg" /isolinux/live.cfg \
    -map "$PROJECT_DIR/assets/installer/creamos-splash.png" /isolinux/splash.png \
    -map "$PROJECT_DIR/assets/installer/creamos-splash.png" /boot/grub/splash.png \
    -map "$PROJECT_DIR/README.md" /README.md \
    -map "$PROJECT_DIR/assets/installer/build-id" /CreamOS/cream-desktop-v2 \
    -map "$PROJECT_DIR/assets" /CreamOS/assets \
    -map "$PROJECT_DIR/scripts" /CreamOS/scripts \
    -commit \
    -end

if ! xorriso -indev "$OUTPUT_ISO" -report_el_torito plain >/dev/null 2>&1 \
    || ! xorriso -indev "$OUTPUT_ISO" -ls /live 2>/dev/null | grep -Fq cream.squashfs \
    || ! xorriso -indev "$OUTPUT_ISO" -ls /live 2>/dev/null | grep -Fq filesystem.module; then
    printf 'Error: generated CreamOS ISO failed boot or module verification: %s\n' "$OUTPUT_ISO" >&2
    exit 1
fi

printf 'Created bootable CreamOS Debian XFCE installer ISO: %s\n' "$OUTPUT_ISO"
