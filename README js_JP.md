<div align="center">
 <b>🌐 Languages:</b>
 <a href="README.md">英語</a> |
 <a href="README zh_CN.md">简体中文</a> |
 <a href="README zh_TW.md">繁體中文</a> |
 <a href="README kr_KO.md">한국어</a>
</div>

---
#CreamOS b0.0.01

CreamOS は、Debian 13 と XFCE をベースにした x86_64 Linux デスクトップです。そのライブ インストーラーには、CreamOS ブランド、Calamares グラフィカル インストーラー、Google Chrome、および MiSans フォントが含まれています。

## 言語と外見

ランチャーは Mac の中国語または英語に従います。 `OPENCREAM_LANGUAGE=en` または `OPENCREAM_LANGUAGE=zh` を設定してオーバーライドします。 CreamOS ブート メニューから中国語または英語を選択します。 Calamares は、インストール時に言語とロケールの選択も提供します。インストールされた XFCE デスクトップは、選択された Debian ロケールと利用可能な Debian 翻訳を使用します。 Debian に翻訳が存在する場合は、追加のロケールをそこで選択できます。

**マテリアル 3**、**液体ガラス**、**テクスチャ** GTK テーマは、**設定 → 外観 → スタイル** で利用できます。液体ガラスは、GTK と互換性のある半透明の視覚処理です。 GTK 3 は、システム全体の背景ブラーを提供しません。

MiSans CJK および Latin フォントはデフォルトでインストールされ、Debian の Noto CJK フォントはフォールバックとして保持されます。フォント アセットは Xiaomi の [MiSans ダウンロード ページ](https://hyperos.mi.com/font/en/) からのものです。

## macOS 上でビルドして起動する

[`OpenCream.command`](./OpenCream.command) をダブルクリックします。単一の `build/CreamOS_installer.iso` をビルドし、QEMU または UTM の使用を提供します。既存の CreamOS ISO を更新する場合、Debian を再度ダウンロードするのではなく、そのイメージをベースとして再利用します。 Google Chrome は、Google の公式 Debian パッケージ URL から一度ダウンロードされ、`~/Library/Caches/CreamOS` の下にキャッシュされます。ビルダーは、CreamOS デスクトップと Calamares ブランドをライブ イメージの上に重ね、BIOS と UEFI ブートのサポートを保持します。

最初の QEMU の起動では、`build/creamos-debian.qcow2` に別の 32 GiB 仮想ディスクが作成されます。ライブ XFCE デスクトップで、**Install CreamOS** をダブルクリックし、グラフィカル インストーラーに従います。インストール後にシャットダウンし、「OpenCream.command」を実行して、**インストールされている CreamOS 仮想ディスクを起動** を選択します。既存の仮想ディスクは上書きされません。

スクリプトは、Homebrew に不足しているビルド ツール `xorriso` と `squashfs` をインストールするように要求します。 QEMU は QEMU の起動にのみ必要です。ダウンロードが中断された場合、「.part」ファイルは保持され、次回から再開されます。

### UTM

[**Show the ISO in Finder**] を選択し、UTM で少なくとも 2 GiB RAM を備えた x86_64 仮想マシンを作成し、`build/CreamOS_installer.iso` をアタッチして、32 GiB 仮想ディスクを作成します。 Apple Silicon Mac では、x86_64 エミュレーションを使用する必要があります。

### コマンドライン

```sh
sh scripts/build-installer-iso.sh /absolute/path/to/debian-live-13.7.0-amd64-xfce.iso
sh scripts/create-disk.sh
OPENCREAM_BOOT_ISO="$PWD/build/CreamOS_installer.iso" sh scripts/run-qemu.sh
```

デフォルトの QEMU ディスク パスは `build/creamos-debian.qcow2` です。 `OPENCREAM_DISK=/path/to/disk.qcow2` でオーバーライドします。 QEMU メモリを変更するには `OPENCREAM_MEMORY` を設定します。 `scripts/boot-installer.sh` は、同じ対話型ランチャーを開きます。

## デスクトップとパッケージ

ライブ デスクトップと Calamares インストーラーは CreamOS ブランドを使用します。また、インストーラーは、3 つの GTK テーマすべて、MiSans、Google Chrome、壁紙、インストーラー リソース、および `install-opencream.sh` を含む CreamOS モジュールを、インストールされているシステムに適用します。

互換性のある Debian amd64 システムでは、デスクトップ セットアップ スクリプトで既存のアカウントのデスクトップとテーマをインストールすることもできます。 Chrome がまだインストールされていない場合は、Google から Google Chrome をダウンロードします。

```sh
sudo sh scripts/install-opencream.sh USERNAME
```

APT はシステム パッケージ マネージャーです。 「opencream-rpm」は個別の RPM パッケージ操作を提供します。 RPM の依存関係は APT の依存関係に変換されず、RPM パッケージは Debian と互換性がない可能性があります。

## カスタム カーネル

QEMU は、インストールされているシステムのブートローダーの代わりに、提供されたカーネルと initrd を起動できます。

```sh
OPENCREAM_KERNEL=/path/to/bzImage \
OPENCREAM_INITRD=/path/to/initramfs \
OPENCREAM_KERNEL_APPEND='root=/dev/vda2 rootwait rw' \
sh scripts/run-qemu.sh
```

ルート パーティションはインストール レイアウトによって異なります。まずはデフォルトの Debian カーネルから確認してください。カスタム カーネルには、必要な virtio ディスク、ファイルシステム、およびコンソール ドライバーが含まれている必要があります。 `OPENCREAM_KERNEL`を設定する場合は、`OPENCREAM_KERNEL_APPEND`が必要です。

### 実験用 Rust グラフィックス カーネル

`scripts/run-rust-kernel.sh` は、別の `no_std` Rust カーネルを構築し、BIOS ブート イメージを作成し、QEMU で起動します。フレームバッファ デモでは、アニメーション化されたマテリアル 3 パレットと半透明の液体ガラス スタイルのパネルが継続的にレンダリングされます。これは、Rust ナイトリー ツールチェーンと「x86_64-unknown-none」ターゲットを使用します。 QEMUも必要です。

これはグラフィックス カーネルのプロトタイプであり、Debian に代わるものではありません。プロセス スケジューリング、ストレージ、ネットワーク、インストーラー、DEB/EXE/DLL の互換性はまだ提供されていません。既存の CreamOS デスクトップは Debian 13 + XFCE のままです。
