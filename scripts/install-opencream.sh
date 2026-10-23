#!/bin/sh
set -eu

VERSION=b0.0.01
TARGET_USER=${1:-}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=${OPENCREAM_SOURCE:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
CHROME_DEB=

cleanup() {
    if [ -n "$CHROME_DEB" ] && [ -f "$CHROME_DEB" ]; then
        rm -f -- "$CHROME_DEB"
    fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

if [ "$(id -u)" -ne 0 ]; then
    printf '%s\n' "Error: run this installer as root (for example: sudo sh install-opencream.sh USER)." >&2
    exit 1
fi

if [ "$(dpkg --print-architecture)" != amd64 ]; then
    printf '%s\n' "Error: OpenCream OS $VERSION currently targets Debian amd64." >&2
    exit 1
fi

if ! grep -q '^ID=debian$' /etc/os-release; then
    printf '%s\n' "Error: install OpenCream OS on Debian 13 or a compatible Debian system." >&2
    exit 1
fi

if [ -z "$TARGET_USER" ]; then
    printf '%s\n' "Usage: install-opencream.sh USERNAME" >&2
    printf '%s\n' "The target must be an existing, non-root user with a home directory." >&2
    exit 2
fi

if [ "$TARGET_USER" = root ] || ! id "$TARGET_USER" >/dev/null 2>&1; then
    printf 'Error: user must be an existing non-root account: %s\n' "$TARGET_USER" >&2
    exit 1
fi

TARGET_UID=$(id -u "$TARGET_USER")
TARGET_GROUP=$(id -gn "$TARGET_USER")
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
if [ "$TARGET_UID" -eq 0 ] || [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
    printf 'Error: user must have a home directory and non-root UID: %s\n' "$TARGET_USER" >&2
    exit 1
fi

if [ ! -f "$PROJECT_ROOT/assets/gtk/Material3/gtk-3.0/gtk.css" ] \
    || [ ! -f "$PROJECT_ROOT/assets/gtk/LiquidGlass/gtk-3.0/gtk.css" ] \
    || [ ! -f "$PROJECT_ROOT/assets/gtk/Texture/gtk-3.0/gtk.css" ] \
    || [ ! -f "$PROJECT_ROOT/vendor/fonts/MiSans-Regular.ttf" ] \
    || [ ! -f "$PROJECT_ROOT/vendor/fonts/MiSansLatin-Regular.ttf" ] \
    || [ ! -f "$PROJECT_ROOT/assets/installer/creamos-wallpaper.svg" ] \
    || [ ! -f "$PROJECT_ROOT/assets/installer/cream-session-branding" ] \
    || [ ! -f "$PROJECT_ROOT/assets/opencream-rpm" ]; then
    printf 'Error: OpenCream source assets not found under %s.\n' "$PROJECT_ROOT" >&2
    printf '%s\n' "Set OPENCREAM_SOURCE to the directory containing the assets/ and scripts/ folders." >&2
    exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
    cpio \
    curl \
    dbus-x11 \
    fonts-liberation \
    fonts-noto-cjk \
    lightdm \
    lightdm-gtk-greeter \
    rpm \
    rpm2cpio \
    xfce4

if ! command -v google-chrome-stable >/dev/null 2>&1; then
    CHROME_DEB=$(mktemp /tmp/creamos-google-chrome.XXXXXX.deb)
    curl -fL --retry 3 \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        -o "$CHROME_DEB"
    DEBIAN_FRONTEND=noninteractive apt-get install --yes "$CHROME_DEB"
fi

install -d -m 0755 \
    /usr/share/backgrounds/creamos \
    /usr/share/doc/fonts-misans \
    /usr/share/fonts/truetype/misans \
    /usr/share/opencream \
    /usr/share/themes/Material3/gtk-3.0 \
    /usr/share/themes/LiquidGlass/gtk-3.0 \
    /usr/share/themes/Texture/gtk-3.0 \
    /usr/local/bin
for theme in Material3 LiquidGlass Texture; do
    install -m 0644 "$PROJECT_ROOT/assets/gtk/$theme/index.theme" \
        "/usr/share/themes/$theme/index.theme"
    install -m 0644 "$PROJECT_ROOT/assets/gtk/$theme/gtk-3.0/gtk.css" \
        "/usr/share/themes/$theme/gtk-3.0/gtk.css"
done
install -m 0644 "$PROJECT_ROOT/vendor/fonts/MiSans-Regular.ttf" \
    /usr/share/fonts/truetype/misans/
install -m 0644 "$PROJECT_ROOT/vendor/fonts/MiSansLatin-Regular.ttf" \
    /usr/share/fonts/truetype/misans/
install -m 0644 "$PROJECT_ROOT/vendor/fonts/README.md" \
    /usr/share/doc/fonts-misans/README
install -m 0644 "$PROJECT_ROOT/assets/installer/creamos-wallpaper.svg" \
    /usr/share/backgrounds/creamos/creamos-wallpaper.svg
install -m 0644 "$PROJECT_ROOT/assets/picom.conf" /usr/share/opencream/picom.conf
install -m 0755 "$PROJECT_ROOT/assets/opencream-rpm" /usr/local/bin/opencream-rpm
install -m 0755 "$PROJECT_ROOT/assets/installer/cream-session-branding" \
    /usr/local/bin/cream-session-branding
install -d -m 0755 /etc/xdg/autostart
install -m 0644 "$PROJECT_ROOT/assets/installer/cream-session-branding.desktop" \
    /etc/xdg/autostart/cream-session-branding.desktop

install -d -m 0755 \
    /etc/skel/.config/gtk-3.0 \
    /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
if [ ! -e /etc/skel/.config/gtk-3.0/settings.ini ]; then
    cat > /etc/skel/.config/gtk-3.0/settings.ini <<'EOF'
[Settings]
gtk-theme-name=Material3
gtk-font-name=MiSans 10
gtk-application-prefer-dark-theme=false
EOF
    chmod 0644 /etc/skel/.config/gtk-3.0/settings.ini
fi
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml <<'EOF'
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

USER_CONFIG="$TARGET_HOME/.config/gtk-3.0"
install -d -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0755 "$USER_CONFIG"
if [ ! -e "$USER_CONFIG/settings.ini" ]; then
    install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0644 \
        /etc/skel/.config/gtk-3.0/settings.ini "$USER_CONFIG/settings.ini"
fi
fc-cache -f /usr/share/fonts/truetype/misans

printf '\nCreamOS %s desktop installed for %s.\n' "$VERSION" "$TARGET_USER"
printf '%s\n' "Choose Material 3, Liquid Glass, or Texture in XFCE Appearance settings."
printf '%s\n' "RPM packages are managed separately from APT."
