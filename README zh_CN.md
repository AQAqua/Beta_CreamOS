<div align="center">
 <b>🌐Languages:</b>
 <a href="README.md">English</a> |
 <a href="README_zh_CN.md">简体中文</a> |
 <a href="README_zh_TW.md">繁體中文</a> |
 <a href="README_js_JP.md">日本語</a> |
 <a href="README_kr_KO.md">한국어</a>
</div>

---
# CreamOS b0.0.01

CreamOS 是基于 Debian 13 和 XFCE 的 x86_64 Linux 桌面。其实时安装程序包括 CreamOS 品牌、Calamares 图形安装程序、Google Chrome 和 MiSans 字体。

## 语言和外观

启动器支持Mac的中文或英文；设置 `OPENCREAM_LANGUAGE=en` 或 `OPENCREAM_LANGUAGE=zh` 来覆盖它。从 CreamOS 启动菜单中选择中文或英文。 Calamares 还在安装过程中提供了语言和区域设置选项；安装的 XFCE 桌面使用选定的 Debian 语言环境和可用的 Debian 翻译。当 Debian 中存在其他语言环境的翻译时，可以在那里选择其他语言环境。

**Material 3**、**液态玻璃**和 **材质** GTK 主题可在 **设置 → 外观 → 样式** 中使用。 Liquid Glass 是一种兼容 GTK 的半透明视觉处理； GTK 3 不提供系统范围的背景模糊。

默认情况下安装 MiSans CJK 和 Latin 字体，并保留 Debian 的 Noto CJK 字体作为后备。字体资源来自小米的[MiSans下载页面](https://hyperos.mi.com/font/en/)。

## 在 macOS 上构建并启动

双击 [`OpenCream.command`](./OpenCream.command)。它构建单个“build/CreamOS_installer.iso”并提供 QEMU 或 UTM 使用。更新现有 CreamOS ISO 时，它会重复使用该映像作为基础，而不是再次下载 Debian。 Google Chrome 是从 Google 官方 Debian 软件包 URL 下载一次并缓存在 `~/Library/Caches/CreamOS` 下；构建器将 CreamOS 桌面和 Calamares 品牌叠加在实时映像上，并保留 BIOS 和 UEFI 启动支持。

第一次 QEMU 启动会在“build/creamos-debian.qcow2”处创建一个单独的 32 GiB 虚拟磁盘。在实时 XFCE 桌面中，双击 **安装 CreamOS** 并按照图形安装程序进行操作。安装后关闭，然后运行`OpenCream.command`并选择**启动已安装的CreamOS虚拟磁盘**。现有虚拟磁盘不会被覆盖。

该脚本要求使用 Homebrew 安装缺少的构建工具：“xorriso”和“squashfs”；仅在 QEMU 启动时才需要 QEMU。如果下载中断，则保留“.part”文件并在下次下载时恢复。

### UTM

选择 **在 Finder 中显示 ISO**，在 UTM 中创建一个至少具有 2 GiB RAM 的 x86_64 虚拟机，附加 `build/CreamOS_installer.iso`，并创建一个 32 GiB 虚拟磁盘。 Apple Silicon Mac 应使用 x86_64 仿真。

### 命令行

```sh
sh scripts/build-installer-iso.sh /absolute/path/to/debian-live-13.7.0-amd64-xfce.iso
sh scripts/create-disk.sh
OPENCREAM_BOOT_ISO="$PWD/build/CreamOS_installer.iso" sh scripts/run-qemu.sh
```

默认的 QEMU 磁盘路径是 `build/creamos-debian.qcow2`；使用“OPENCREAM_DISK=/path/to/disk.qcow2”覆盖它。设置`OPENCREAM_MEMORY`来更改QEMU内存。 `scripts/boot-installer.sh` 打开相同的交互式启动器。

## 桌面和软件包

实时桌面和 Calamares 安装程序使用 CreamOS 品牌。安装程序还将 CreamOS 模块应用到已安装的系统，包括所有三个 GTK 主题、MiSans、Google Chrome、壁纸、安装程序资源和“install-opencream.sh”。

在兼容的 Debian amd64 系统上，桌面设置脚本还可以为现有帐户安装桌面和主题。当 Chrome 尚未安装时，它会从 Google 下载 Google Chrome：

````嘘
sudo sh 脚本/install-opencream.sh 用户名
````

APT 是系统包管理器。 `opencream-rpm` 提供单独的 RPM 包操作；它不会将 RPM 依赖项转换为 APT 依赖项，并且 RPM 软件包可能与 Debian 不兼容。

## 自定义内核

QEMU 可以引导提供的内核和 initrd，而不是已安装系统的引导加载程序：

```sh
sh scripts/build-installer-iso.sh /absolute/path/to/debian-live-13.7.0-amd64-xfce.iso
sh scripts/create-disk.sh
OPENCREAM_BOOT_ISO="$PWD/build/CreamOS_installer.iso" sh scripts/run-qemu.sh
```

根分区取决于安装布局。首先从默认的 Debian 内核进行确认。自定义内核必须包含所需的 virtio 磁盘、文件系统和控制台驱动程序。设置“OPENCREAM_KERNEL”时需要“OPENCREAM_KERNEL_APPEND”。

### 实验 Rust 图形内核

`scripts/run-rust-kernel.sh` 构建一个单独的 `no_std` Rust 内核，创建 BIOS 启动映像，并在 QEMU 中启动它。帧缓冲区演示连续渲染动画 Material 3 调色板和半透明液体玻璃样式面板。它使用 Rust nightly 工具链和 `x86_64-unknown-none` 目标；还需要 QEMU。

这是一个图形内核原型，而不是 Debian 的替代品：它尚未提供进程调度、存储、网络、安装程序或 DEB/EXE/DLL 兼容性。现有的 CreamOS 桌面仍然是 Debian 13 + XFCE。