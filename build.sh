#!/usr/bin/env bash
# ============================================================
#  build.sh —— 一键构建自己的 iStoreOS 固件
#  必须跑在 Linux（或 WSL / GitHub Actions）上，Windows 原生不行
#  用法：  bash build.sh
#  产物：  .src/istoreos/bin/targets/x86/64/*.img.gz
#  日志：  构建全过程写入仓库根目录 build.log（便于排查）
# ============================================================

set -Eeuo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
[ -f "$ROOT/device.conf" ] || { echo "请在仓库根目录运行"; exit 1; }
. "$ROOT/device.conf"

# ---------- 日志：控制台 + build.log 双写 ----------
LOG="$ROOT/build.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

# ---------- 出错时提示 ----------
trap 'echo "!! 构建在脚本第 $LINENO 行失败，详见上面的输出与 build.log"' ERR
trap 'echo "------------------------------------------------" ; echo "build.log 路径：$LOG"' EXIT

BRANCH="${BRANCH:-openwrt-25.12}"
REPO="${REPO:-https://github.com/istoreos/istoreos.git}"
SRC="${SRC:-$ROOT/.src/istoreos}"

# ---------- 并发数：看内存自动降，防 OOM ----------
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 2)}"
MEM_GB=$(awk '/MemTotal/{printf "%d", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo 8)
if [ "$MEM_GB" -lt 8 ]; then
	echo "[内存 ${MEM_GB}GB < 8GB] 并发自动降到 2，避免编译被 OOM 杀掉"
	JOBS=2
fi

echo "======================================================"
echo " 构建目标：$BRAND_NAME  (hostname=$DEVICE_NAME)"
echo " 编译者：$BUILDER_NAME   日期：$(date '+%Y-%m-%d %H:%M')"
echo " 管理：$LAN_IP   模式：$MODE   主题：$THEME"
echo " 分区：内核 ${KERNEL_SIZE_MB}MB / 系统 ${ROOTFS_SIZE_MB}MB"
echo " 并发：JOBS=$JOBS   内存：${MEM_GB}GB"
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
# 个别 feed（如 oaf）在新内核上可能安装报错；不让它中断整体构建，
# 装不上的包会被 make 阶段跳过，最终在“未编入汇总”里列出。
./scripts/feeds update -a || echo "[警告] feeds update 部分失败，继续"
./scripts/feeds install -a || echo "[警告] feeds install 部分失败（个别包可能不可用），继续构建"

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
# IGNORE_ERRORS=1：个别包（如 oaf 内核模块）在新内核上可能编不过，
# 跳过它也能照样出固件；失败的包会在下方汇总里列出，方便你决定要不要单独修。
echo "[7/7] 开始编译（首次 1-3 小时，之后增量 10-30 分钟）"
echo "       提示：个别包失败不会中断，最终会列出哪些包没编入。"
make download -j"$JOBS" || echo "部分源码下载失败，编译时会重试"
make -j"$JOBS" V=s IGNORE_ERRORS=1 || echo "[警告] make 返回非零，可能部分包未编入；继续检查产物"

# ---------- 8. 汇总失败包 ----------
echo ""
echo "======================================================"
echo " 编译结束，检查未编入的包（如有说明它们被跳过了）："
echo "======================================================"
grep -iE "ERROR:|failed to build|is not available|error: " "$LOG" \
	| grep -ivE "error: code|error code|strerror" \
	| sed 's/^/   /' | tail -25 || true

# ---------- 9. 产物 ----------
if ls bin/targets/x86/64/*.img.gz >/dev/null 2>&1; then
	echo ""
	echo " 固件已生成："
	ls -lh bin/targets/x86/64/*.img.gz
	echo "======================================================"
	echo " 完成！固件在：bin/targets/x86/64/*.img.gz"
	echo "======================================================"
else
	echo ""
	echo "ERROR: 未生成 img.gz，构建未完成。请查看 build.log 末尾的错误。"
	exit 1
fi
