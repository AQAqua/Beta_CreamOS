<div align="center">
 <b>🌐Languages:</b>
 <a href="README.md">English</a> |
 <a href="README zh_CN.md">簡體中文</a> |
 <a href="README js_JP.md">日本語</a> |
 <a href="README kr_KO.md">한국어</a>
</div>

---
# CreamOS b0.0.01

CreamOS 是基於 Debian 13 和 XFCE 的 x86_64 Linux 桌面。其實即時安裝程式包括 CreamOS 品牌、Calamares 圖形安裝程式、Google Chrome 和 MiSans 字型。

## 語言和外觀

啟動器支援Mac的中文或英文；設定 `OPENCREAM_LANGUAGE=en` 或 `OPENCREAM_LANGUAGE=zh` 來覆寫它。從 CreamOS 啟動選單中選擇中文或英文。 Calamares 還在安裝過程中提供了語言和區域設定選項；安裝的 XFCE 桌面使用選定的 Debian 語言環境和可用的 Debian 翻譯。當 Debian 中存在其他語言環境的翻譯時，可以在那裡選擇其他語言環境。

**Material 3**、**液態玻璃**和 **材質** GTK 主題可在 **設定 → 外觀 → 樣式** 中使用。 Liquid Glass 是一種相容於 GTK 的半透明視覺處理； GTK 3 不提供系統範圍的背景模糊。

預設安裝 MiSans CJK 和 Latin 字體，並保留 Debian 的 Noto CJK 字體作為備用。字型資源來自小米的[MiSans下載頁](https://hyperos.mi.com/font/en/)。

## 在 macOS 上建置並啟動

雙擊 [`OpenCream.command`](./OpenCream.command)。它建立單一“build/CreamOS_installer.iso”並提供 QEMU 或 UTM 使用。更新現有 CreamOS ISO 時，它會重複使用該映像作為基礎，而不是再次下載 Debian。 Google Chrome 是從 Google 官方 Debian 軟體包 URL 下載一次並快取在 `~/Library/Caches/CreamOS` 下；建構器將 CreamOS 桌面和 Calamares 品牌疊加在即時映像上，並保留 BIOS 和 UEFI 啟動支援。

第一次 QEMU 啟動會在「build/creamos-debian.qcow2」處建立一個單獨的 32 GiB 虛擬磁碟。在即時 XFCE 桌面中，按兩下 **安裝 CreamOS** 並依照圖形安裝程式進行操作。安裝後關閉，然後執行`OpenCream.command`並選擇**啟動已安裝的CreamOS虛擬磁碟**。現有虛擬磁碟不會被覆蓋。

該腳本要求使用 Homebrew 安裝缺少的建置工具：「xorriso」和「squashfs」；僅在 QEMU 啟動時才需要 QEMU。如果下載中斷，則保留“.part”檔案並在下次下載時恢復。

### UTM

選擇 **在 Finder 中顯示 ISO**，在 UTM 中建立一個至少具有 2 GiB RAM 的 x86_64 虛擬機，附加 `build/CreamOS_installer.iso`，並建立一個 32 GiB 虛擬磁碟。 Apple Silicon Mac 應使用 x86_64 模擬。

### 命令列

```sh
sh scripts/build-installer-iso.sh /absolute/path/to/debian-live-13.7.0-amd64-xfce.iso
sh scripts/create-disk.sh
OPENCREAM_BOOT_ISO="$PWD/build/CreamOS_installer.iso" sh scripts/run-qemu.sh
```

預設的 QEMU 磁碟路徑是 `build/creamos-debian.qcow2`；使用“OPENCREAM_DISK=/path/to/disk.qcow2”覆蓋它。設定`OPENCREAM_MEMORY`來更改QEMU記憶體。 `scripts/boot-installer.sh` 開啟相同的互動式啟動器。

## 桌面和軟體包

即時桌面和 Calamares 安裝程式使用 CreamOS 品牌。安裝程式還將 CreamOS 模組應用到已安裝的系統，包括所有三個 GTK 主題、MiSans、Google Chrome、桌布、安裝程式資源和「install-opencream.sh」。

在相容的 Debian amd64 系統上，桌面設定腳本還可以為現有帳戶安裝桌面和主題。當 Chrome 尚未安裝時，它會從 Google 下載 Google Chrome：

````噓
sudo sh 腳本/install-opencream.sh 使用者名稱
````

APT 是系統套件管理器。 `opencream-rpm` 提供單獨的 RPM 套件操作；它不會將 RPM 依賴項轉換為 APT 依賴項，且 RPM 軟體包可能與 Debian 不相容。

## 自訂內核

QEMU 可以引導提供的核心和 initrd，而不是已安裝系統的引導程式：

```sh
sh scripts/build-installer-iso.sh /absolute/path/to/debian-live-13.7.0-amd64-xfce.iso
sh scripts/create-disk.sh
OPENCREAM_BOOT_ISO="$PWD/build/CreamOS_installer.iso" sh scripts/run-qemu.sh
```

根分割區取決於安裝佈局。首先從預設的 Debian 核心進行確認。自訂核心必須包含所需的 virtio 磁碟、檔案系統和控制台驅動程式。設定“OPENCREAM_KERNEL”時需要“OPENCREAM_KERNEL_APPEND”。

### 實驗 Rust 圖形內核

`scripts/run-rust-kernel.sh` 建立一個單獨的 `no_std` Rust 內核，建立 BIOS 啟動映像，並在 QEMU 中啟動它。幀緩衝區演示連續渲染動畫 Material 3 調色板和半透明液體玻璃樣式面板。它使用 Rust nightly 工具鏈和 `x86_64-unknown-none` 目標；還需要 QEMU。

這是一個圖形核心原型，而不是 Debian 的替代品：它尚未提供進程調度、儲存、網路、安裝程式或 DEB/EXE/DLL 相容性。現有的 CreamOS 桌面仍然是 Debian 13 + XFCE。
