#!/usr/bin/env bash
# ============================================================
# 本机（WSL2 / Debian / Ubuntu）编译 Nokia XG-040G-MD 固件
# 用法：
#   1) 把整个 xg040gmd-build 目录放到 WSL 内部家目录（不要放在 /mnt/c，NTFS 大小写不敏感会直接编译失败）
#      正确做法：在 Windows 上先建目录并开启大小写敏感，然后让 WSL 通过 /mnt/c 访问？不行。
#      → 推荐直接放进 WSL 的 ext4：cp -r /mnt/c/Users/g4560/WorkBuddy/xxx/xg040gmd-build ~/ && cd ~/xg040gmd-build
#   2) bash scripts/local-build.sh
# 预计：磁盘 40GB+，时间 1~3 小时（视网络）
# ============================================================
set -euo pipefail

REPO_URL="https://github.com/coolsnowwolf/lede"
REPO_BRANCH="master"
WORKDIR="${WORKDIR:-$HOME/lede-build}"
CONFIG_FILE="$(cd "$(dirname "$0")/.." && pwd)/configs/xg040g-md.config"
FILES_DIR="$(cd "$(dirname "$0")/.." && pwd)/files"
DEVICE_SYMBOL="CONFIG_TARGET_airoha_an7581_DEVICE_nokia_xg-040g-md-ubi"
JOBS="${JOBS:-$(nproc)}"

echo "==> 工作目录: $WORKDIR"
echo "==> 并发数:   $JOBS"

if [ "$(id -u)" = "0" ]; then
  echo "!! 不要用 root 编译，请切换到普通用户执行" >&2
  exit 1
fi

# --- 磁盘空间检查 ---
avail=$(df -BG --output=avail "$(dirname "$WORKDIR")" | tail -1 | tr -dc '0-9')
if [ "$avail" -lt 40 ]; then
  echo "!! 可用空间只有 ${avail}GB，建议 40GB 以上，退出" >&2
  exit 1
fi

# --- 依赖 ---
if ! command -v make >/dev/null 2>&1 || ! command -v gcc >/dev/null 2>&1; then
  echo "==> 安装编译依赖（需要 sudo）"
  sudo apt-get update -y
  sudo apt-get install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison \
    build-essential bzip2 ccache clang cmake cpio curl device-tree-compiler flex gawk \
    gcc-multilib g++-multilib gettext genisoimage git gperf haveged help2man intltool \
    libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev libgmp3-dev libltdl-dev \
    libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libpython3-dev \
    libreadline-dev libssl-dev libtool llvm lrzsz libnsl-dev ninja-build p7zip \
    p7zip-full patch pkgconf python3 python3-pyelftools python3-setuptools qemu-utils \
    rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim \
    wget xmlto xxd xz-utils zlib1g-dev
fi

# --- 源码 ---
mkdir -p "$WORKDIR"
cd "$WORKDIR"
if [ ! -d lede/.git ]; then
  echo "==> 克隆 lede 源码"
  git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" lede
else
  echo "==> 复用已有源码，执行 git pull"
  cd lede && git pull --ff-only || true; cd "$WORKDIR"
fi

# --- 大小写敏感检查（NTFS 会失败） ---
if [ -f /proc/mounts ] && mountpoint -q -- "$(df --output=target "$WORKDIR" | tail -1)" 2>/dev/null; then :; fi
fs_type=$(df -T "$WORKDIR" | tail -1 | awk '{print $2}')
echo "==> 文件系统类型: $fs_type"
case "$fs_type" in
  drvfs|9p|cifs|vboxsf|ntfs*)
    echo "!! 当前目录在 $fs_type 文件系统上，OpenWrt 会报 'case-sensitive filesystem' 错误。" >&2
    echo "   请把工程移到 WSL 的 ext4（例如 ~/lede-build）后重试。" >&2
    exit 1
    ;;
esac

# --- feeds ---
cd "$WORKDIR/lede"
echo "==> 挂载 QModem feed（4G/5G 模组管理）"
grep -q "src-git qmodem" feeds.conf.default || \
  echo "src-git qmodem https://github.com/FUjr/QModem.git" >> feeds.conf.default

echo "==> 更新 feeds（国内网络建议先配好代理，否则可能很慢）"
./scripts/feeds update -a
./scripts/feeds install -a

# --- 默认配置（flow offloading / BBR） ---
echo "==> 注入默认配置文件"
mkdir -p files
cp -r "$FILES_DIR/." files/
chmod +x files/etc/uci-defaults/* 2>/dev/null || true

# --- 配置 ---
echo "==> 应用配置"
cp "$CONFIG_FILE" .config
make defconfig
if ! grep -q "^$DEVICE_SYMBOL=y" .config; then
  echo "==> 设备符号未命中，用 TARGET_PROFILE 兜底"
  sed -i '/^CONFIG_TARGET_PROFILE=/d' .config
  echo 'CONFIG_TARGET_PROFILE="DEVICE_nokia_xg-040g-md-ubi"' >> .config
  make defconfig
fi
grep -q "^$DEVICE_SYMBOL=y" .config || { echo "!! 机型未选中，终止" >&2; exit 1; }
echo "==> 机型校验通过"

# --- 下载 / 编译 ---
echo "==> 下载源码包（十几 GB，第一次很久）"
make download -j8 || make download -j1 V=s

echo "==> 开始编译，日志同时写入 build.log"
if ! make -j"$JOBS" V=s 2>&1 | tee build.log | tail -n 5 ; then :; fi
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "!! 编译失败，看 build.log 末尾" >&2; exit 1; }

echo "==> 完成，产物在: $WORKDIR/lede/bin/targets/airoha/an7581/"
ls -lh bin/targets/airoha/an7581/
