# CreamOS b0.0.01

CreamOS is an x86_64 Linux desktop based on Debian 13 and XFCE. Its live installer includes CreamOS branding, the Calamares graphical installer, Google Chrome, and MiSans fonts.

## Languages and appearance

The launcher follows the Mac's Chinese or English language; set `OPENCREAM_LANGUAGE=en` or `OPENCREAM_LANGUAGE=zh` to override it. Choose Chinese or English from the CreamOS boot menu. Calamares also provides its language and locale choices during installation; the installed XFCE desktop uses the selected Debian locale and available Debian translations. Additional locales can be selected there when their translations are present in Debian.

The **Material 3**, **Liquid Glass**, and **Texture** GTK themes are available in **Settings → Appearance → Style**. Liquid Glass is a GTK-compatible translucent visual treatment; GTK 3 does not provide system-wide background blur.

MiSans CJK and Latin fonts are installed by default, with Debian's Noto CJK fonts retained as fallback. Font assets are from Xiaomi's [MiSans download page](https://hyperos.mi.com/font/en/).

## Build and start on macOS

Double-click [`OpenCream.command`](./OpenCream.command). It builds the single `build/CreamOS_installer.iso` and offers QEMU or UTM use. When updating an existing CreamOS ISO, it reuses that image as the base rather than downloading Debian again. Google Chrome is downloaded from Google's official Debian package URL once and cached under `~/Library/Caches/CreamOS`; the builder layers the CreamOS desktop and Calamares branding over the live image and retains BIOS and UEFI boot support.

The first QEMU launch creates a separate 32 GiB virtual disk at `build/creamos-debian.qcow2`. In the live XFCE desktop, double-click **Install CreamOS** and follow the graphical installer. Shut down after installation, then run `OpenCream.command` and choose **Boot the installed CreamOS virtual disk**. Existing virtual disks are not overwritten.

The script asks to install missing build tools with Homebrew: `xorriso` and `squashfs`; QEMU is needed only for QEMU launch. If the download is interrupted, the `.part` file is kept and resumed next time.

### UTM

Choose **Show the ISO in Finder**, create an x86_64 virtual machine in UTM with at least 2 GiB RAM, attach `build/CreamOS_installer.iso`, and create a 32 GiB virtual disk. Apple Silicon Macs should use x86_64 emulation.

### Command line

```sh
sh scripts/build-installer-iso.sh /absolute/path/to/debian-live-13.7.0-amd64-xfce.iso
sh scripts/create-disk.sh
OPENCREAM_BOOT_ISO="$PWD/build/CreamOS_installer.iso" sh scripts/run-qemu.sh
```

The default QEMU disk path is `build/creamos-debian.qcow2`; override it with `OPENCREAM_DISK=/path/to/disk.qcow2`. Set `OPENCREAM_MEMORY` to change QEMU memory. `scripts/boot-installer.sh` opens the same interactive launcher.

## Desktop and packages

The live desktop and Calamares installer use CreamOS branding. The installer also applies the CreamOS module to the installed system, including all three GTK themes, MiSans, Google Chrome, wallpaper, installer resources, and `install-opencream.sh`.

On a compatible Debian amd64 system, the desktop setup script can also install the desktop and themes for an existing account. It downloads Google Chrome from Google when Chrome is not already installed:

```sh
sudo sh scripts/install-opencream.sh USERNAME
```

APT is the system package manager. `opencream-rpm` provides separate RPM package operations; it does not translate RPM dependencies into APT dependencies, and RPM packages may not be compatible with Debian.

## Custom kernel

QEMU can boot a supplied kernel and initrd instead of the installed system's bootloader:

```sh
OPENCREAM_KERNEL=/path/to/bzImage \
OPENCREAM_INITRD=/path/to/initramfs \
OPENCREAM_KERNEL_APPEND='root=/dev/vda2 rootwait rw' \
sh scripts/run-qemu.sh
```

The root partition depends on the installation layout. Confirm it from the default Debian kernel first. A custom kernel must include the required virtio disk, filesystem, and console drivers. `OPENCREAM_KERNEL_APPEND` is required when setting `OPENCREAM_KERNEL`.

### Experimental Rust graphics kernel

`scripts/run-rust-kernel.sh` builds a separate `no_std` Rust kernel, creates a BIOS boot image, and starts it in QEMU. The framebuffer demo continuously renders an animated Material 3 palette and translucent Liquid Glass-style panel. It uses the Rust nightly toolchain and the `x86_64-unknown-none` target; QEMU is also required.

This is a graphics-kernel prototype, not a replacement for Debian: it does not yet provide process scheduling, storage, networking, an installer, or DEB/EXE/DLL compatibility. The existing CreamOS desktop remains Debian 13 + XFCE.
