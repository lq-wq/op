#!/bin/sh
# ============================================================
#  build.sh —— 一键构建自己的 iStoreOS 固件
#  必须跑在 Linux（或 WSL / GitHub Actions）上，Windows 原生不行
#  用法：  bash build.sh
#  产物：  .src/istoreos/bin/targets/x86/64/*.img.gz
# ============================================================

set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
[ -f "$ROOT/device.conf" ] || { echo "请在仓库根目录运行"; exit 1; }
. "$ROOT/device.conf"

BRANCH="${BRANCH:-openwrt-25.12}"
REPO="${REPO:-https://github.com/istoreos/istoreos.git}"
SRC="${SRC:-$ROOT/.src/istoreos}"
JOBS="${JOBS:-$(nproc)}"

echo "======================================================"
echo " 构建目标：$BRAND_NAME  (hostname=$DEVICE_NAME)"
echo " 编译者：$BUILDER_NAME   日期：$(date '+%Y-%m-%d %H:%M')"
echo " 管理：$LAN_IP   模式：$MODE   主题：$THEME"
echo " 分区：内核 ${KERNEL_SIZE_MB}MB / 系统 ${ROOTFS_SIZE_MB}MB"
echo " 源码：$REPO  分支：$BRANCH"
echo "======================================================"

# ---------- 1. 拉源码（浅克隆，省时间）----------
mkdir -p "$ROOT/.src"
if [ ! -d "$SRC/.git" ]; then
	echo "[1/7] 克隆 iStoreOS 源码（约 5-10 分钟，首次较慢）"
	git clone --depth 1 -b "$BRANCH" "$REPO" "$SRC"
else
	echo "[1/7] 复用已有源码树"
fi

# ---------- 2. feeds ----------
echo "[2/7] 配置 feeds"
# 注意：OpenWrt 只读 feeds.conf；它存在时 feeds.conf.default 会被忽略。
# 所以必须把官方默认源 + 我们的附加源拼在一起，不能只放附加源。
if [ ! -s "$SRC/feeds.conf.default" ]; then
	echo "缺少 feeds.conf.default，源码树不完整"; exit 1
fi
{
	cat "$SRC/feeds.conf.default"
	echo ""
	echo "# ---- 以下由 istoreos-fw/feeds.conf 追加 ----"
	grep -v '^\s*$' "$ROOT/feeds.conf"
} > "$SRC/feeds.conf"

# ---------- 3. 自己的插件进树 ----------
echo "[3/7] 注入自定义插件 packages/ -> package/myapps"
rm -rf "$SRC/package/myapps"
mkdir -p "$SRC/package/myapps"
if [ -d "$ROOT/packages" ]; then
	cp -a "$ROOT/packages/." "$SRC/package/myapps/"
fi

# ---------- 4. 生成 overlay ----------
echo "[4/7] 渲染 files/ (device.conf -> overlay)"
sh "$ROOT/scripts/render-files.sh"
rm -rf "$SRC/files"
mkdir -p "$SRC/files"
cp -a "$ROOT/build/files/." "$SRC/files/"

cd "$SRC"
./scripts/feeds update -a
./scripts/feeds install -a

# ---------- 5. 改软件显示名 ----------
echo "[5/7] 改软件显示名"
sh "$ROOT/scripts/rename-apps.sh" "$SRC"

# ---------- 6. 生成 .config ----------
echo "[6/7] 生成配置并展开依赖"
{
	cat "$ROOT/configs/x86_64.defconfig"
	echo ""
	echo "# ---- 由 device.conf 自动生成 ----"
	echo "CONFIG_TARGET_KERNEL_PARTSIZE=$KERNEL_SIZE_MB"
	echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$ROOTFS_SIZE_MB"
	echo ""
	echo "# ---- 由 configs/packages.list 自动生成 ----"
	while IFS= read -r p; do
		case "$p" in
			''|\#*) continue ;;
		esac
		# 容忍首尾空白
		p=$(echo "$p" | tr -d ' \t\r')
		[ -z "$p" ] && continue
		echo "CONFIG_PACKAGE_$p=y"
	done < "$ROOT/configs/packages.list"
} > .config

make defconfig

# ---------- 7. 编译 ----------
echo "[7/7] 开始编译（首次 1-3 小时，之后增量 10-30 分钟）"
make download -j"$JOBS" || echo "部分源码下载失败，编译时会重试"
make -j"$JOBS" V=s

echo ""
echo "======================================================"
echo " 完成！固件在："
ls -lh bin/targets/x86/64/*.img.gz 2>/dev/null || echo " 未找到 img.gz，请检查上面日志"
echo "======================================================"
