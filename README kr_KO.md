<div align="center">
 <b>🌐Languages:</b>
 <a href="README.md">English</a> |
 <a href="README zh_CN.md">简体中文</a> |
 <a href="README zh_TW.md">繁體中文</a> |
 <a href="README js_JP.md">日本語</a> |
</div>

---
#CreamOS b0.0.01

CreamOS는 데비안 13 및 XFCE 기반의 x86_64 Linux 데스크톱입니다. 라이브 설치 프로그램에는 CreamOS 브랜드, Calamares 그래픽 설치 프로그램, Google 크롬 및 MiSans 글꼴이 포함됩니다.

## 언어와 외모

런처는 Mac의 중국어 또는 영어를 따릅니다. `OPENCREAM_LANGUAGE=en` 또는 `OPENCREAM_LANGUAGE=zh` (을)를 설정해 오버라이드(override) 합니다. CreamOS 부팅 메뉴에서 중국어 또는 영어를 선택합니다. Calamares는 설치 시 언어 및 로케일 선택도 제공합니다. 설치된 XFCE 데스크톱은 선택한 데비안 로캘과 사용 가능한 데비안 번역을 사용합니다. 데비안에 번역이 있으면 추가 로케일을 선택할 수 있습니다.

**재질 3**, **액체 유리**, **텍스처** GTK 테마는 **설정 → 외관 → 스타일**에서 사용할 수 있습니다. 액체 유리는 GTK와 호환되는 반투명 시각 처리입니다. GTK 3는 전체 시스템에 대한 배경 흐림 효과를 제공하지 않습니다.

MiSans CJK 및 Latin 글꼴은 기본적으로 설치되며 데비안의 Noto CJK 글꼴은 대체로 유지됩니다. 글꼴 자산은 Xiaomi의 MiSans 다운로드 페이지(https://hyperos.mi.com/font/en/)에서 가져옵니다.

## macOS에서 빌드 및 시작

[`OpenCream.command`](./OpenCream.command)를 두 번 클릭합니다. 단일의 `build/CreamOS_installer.iso`를 빌드해, QEMU 또는 UTM의 사용을 제공합니다. 기존 CreamOS ISO를 업데이트하는 경우 데비안을 다시 다운로드하는 대신 이미지를 기반으로 재사용합니다. Google 크롬은 공식 공식 데비안 패키지 URL에서 한 번 다운로드되고`~/Library/Caches/CreamOS` 아래에 캐시됩니다. 빌더는 CreamOS 데스크톱과 Calamares 브랜드를 라이브 이미지 위에 겹쳐서 BIOS 및 UEFI 부팅 지원을 유지합니다.

첫 번째 QEMU 부팅은 `build/creamos-debian.qcow2`에 다른 32 GiB 가상 디스크를 만듭니다. 라이브 XFCE 데스크톱에서 **Install CreamOS**를 두 번 클릭하고 그래픽 설치 프로그램을 따릅니다. 설치 후 종료하고 OpenCream.command를 실행하여 **설치된 CreamOS 가상 디스크 시작**을 선택합니다. 기존 가상 디스크는 덮어쓰지 않습니다.

스크립트는 Homebrew에 누락된 빌드 도구 `xorriso` 및 `squashfs`를 설치하도록 요청합니다. QEMU는 QEMU 시작에만 필요합니다. 다운로드가 중단되면 ".part" 파일이 유지되고 다음 번부터 다시 시작됩니다.

### UTM

**Show the ISO in Finder**를 선택하고 UTM에서 최소 2GiB RAM이 있는 x86_64 가상 머신을 만들고 `build/CreamOS_installer.iso`를 연결하여 32GiB 가상 디스크를 만듭니다. Apple Silicon Mac에서는 x86_64 에뮬레이션을 사용해야 합니다.

### 명령줄

``sh
sh scripts/build-installer-iso.sh /absolute/path/to/debian-live-13.7.0-amd64-xfce.iso
sh scripts/create-disk.sh
OPENCREAM_BOOT_ISO="$PWD/build/CreamOS_installer.iso" sh scripts/run-qemu.sh
``

기본 QEMU 디스크 경로는 `build/creamos-debian.qcow2`입니다. `OPENCREAM_DISK=/path/to/disk.qcow2`로 재정의합니다. QEMU 메모리를 변경하려면 `OPENCREAM_MEMORY`를 설정하십시오. `scripts/boot-installer.sh` 는 같은 대화형 런처를 엽니다.

## 데스크탑 및 패키지

라이브 데스크톱과 Calamares 설치 프로그램은 CreamOS 브랜드를 사용합니다. 또한 설치 프로그램은 세 가지 GTK 테마, MiSans, Google 크롬, 배경 화면, 설치 프로그램 리소스 및 `install-opencream.sh`를 포함하는 CreamOS 모듈을 설치된 시스템에 적용합니다.

호환되는 Debian amd64 시스템을 사용하면 데스크톱 설치 스크립트에서 기존 계정의 데스크톱 및 테마를 설치할 수도 있습니다. Chrome이 아직 설치되어 있지 않은 경우 Google에서 Google Chrome을 다운로드합니다.

``sh
sudo sh scripts/install-opencream.sh USERNAME
``

APT는 시스템 패키지 관리자입니다. opencream-rpm은 별도의 RPM 패키지 작업을 제공합니다. RPM 종속성은 APT 종속성으로 변환되지 않으며 RPM 패키지는 데비안과 호환되지 않을 수 있습니다.

## 커스텀 커널

QEMU는 설치된 시스템의 부트 로더 대신 제공된 커널과 initrd를 시작할 수 있습니다.

``sh
OPENCREAM_KERNEL=/path/to/bzImage\
OPENCREAM_INITRD=/path/to/initramfs\
OPENCREAM_KERNEL_APPEND='root=/dev/vda2 rootwait rw'\
sh scripts/run-qemu.sh
``

루트 파티션은 설치 레이아웃에 따라 다릅니다. 먼저 기본 데비안 커널에서 확인하십시오. 사용자 지정 커널에는 필요한 virtio 디스크, 파일 시스템 및 콘솔 드라이버가 포함되어 있어야 합니다. `OPENCREAM_KERNEL`을 설정하는 경우 `OPENCREAM_KERNEL_APPEND`가 필요합니다.

### 실험용 Rust 그래픽 커널

`scripts/run-rust-kernel.sh` (은)는, 다른 `no_std` Rust 커널을 구축해, BIOS 부트 이미지를 작성해, QEMU 로 기동합니다. 프레임 버퍼 데모는 애니메이션된 머티리얼 3 팔레트와 반투명 액체 유리 스타일 패널을 지속적으로 렌더링합니다. 이것은 Rust 나이트리 툴체인과 "x86_64-unknown-none" 타겟을 사용합니다. QEMU도 필요합니다.

이것은 그래픽 커널의 프로토 타입이며 데비안을 대체하지는 않습니다. 프로세스 스케줄링, 스토리지, 네트워크, 설치 프로그램, DEB/EXE/DLL 호환성은 아직 제공되지 않았습니다. 기존 CreamOS 데스크톱은 Debian 13 + XFCE로 유지됩니다.
