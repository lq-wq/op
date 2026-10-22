#!/bin/sh
# ============================================================
#  render-files.sh —— 把 device.conf 的变量填进 files/ 模板
#  产出：build/files/  （干净的 overlay 目录，直接被 build.sh 拷进源码树）
#
#  性能说明：生成一份 sed 脚本、每个文件只跑一次 sed，
#  避免在 Windows/GitBash 上大量 fork 导致卡死。
# ============================================================

set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/device.conf"

OUT="$ROOT/build/files"
rm -rf "$OUT"
mkdir -p "$OUT"

VARS="DEVICE_NAME BRAND_NAME BRAND_VERSION BRAND_VENDOR BUILDER_NAME BUILD_DATE THEME
LAN_IP LAN_NETMASK LAN_DHCP_START LAN_DHCP_END LAN_DHCP_LEASE
ROOT_PASSWORD MODE WAN_PROTO PPPOE_USER PPPOE_PASS
PORT_POLICY MANUAL_WAN_PORT MANUAL_LAN_PORTS
HOME_BANDWIDTH HW_OFFLOAD
EXTEND_ROOTFS TIMEZONE ZONENAME LANG_CODE NTP_SERVER"

# 个性签名的日期：编译那一刻自动生成（也可用环境变量 BUILD_DATE 覆盖）
BUILD_DATE="${BUILD_DATE:-$(date '+%Y-%m-%d %H:%M')}"

# 生成 sed 替换脚本（纯 shell 转义，不额外 fork）
SEDSCRIPT="$ROOT/build/.sedscript"
: > "$SEDSCRIPT"
for v in $VARS; do
	eval "val=\${$v}"
	esc="${val//\\/\\\\}"
	esc="${esc//|/\\|}"
	esc="${esc//&/\\&}"
	printf 's|@%s@|%s|g\n' "$v" "$esc" >> "$SEDSCRIPT"
done

echo "[render] 生成 overlay -> $OUT"
cd "$ROOT/files"
find . -type f | while IFS= read -r f; do
	case "$f" in
		*.tmpl) dst="${f%.tmpl}" ;;
		*)      dst="$f" ;;
	esac
	mkdir -p "$OUT/$(dirname "$dst")"
	sed -f "$SEDSCRIPT" "$f" > "$OUT/$dst"
done
rm -f "$SEDSCRIPT"

# uci-defaults 必须可执行，否则不会运行（这是最常见的"脚本没生效"原因）
if [ -d "$OUT/etc/uci-defaults" ]; then
	find "$OUT/etc/uci-defaults" -type f -exec chmod 755 {} \;
fi

# 检查有没有漏替换的占位符
leftover=$(grep -rl '@[A-Z_]*@' "$OUT" 2>/dev/null || true)
if [ -n "$leftover" ]; then
	echo "[render] 警告：以下文件还有未替换占位符"
	echo "$leftover"
fi

echo "[render] 完成：$(find "$OUT" -type f | wc -l) 个文件"
