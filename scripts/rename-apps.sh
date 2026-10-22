#!/bin/sh
# ============================================================
#  rename-apps.sh —— 按 brand/apps.tsv 改 LuCI 菜单里的软件显示名
#  用法：rename-apps.sh <源码树路径>
#  原理：改 menu.d/*.json 里的 "title" 字段，不动包名，升级不冲突
# ============================================================

set -eu
SRC="$1"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TSV="$ROOT/brand/apps.tsv"

[ -d "$SRC/feeds/luci" ] || { echo "[rename] 找不到 $SRC/feeds/luci，跳过"; exit 0; }
[ -f "$TSV" ] || { echo "[rename] 没有 apps.tsv，跳过"; exit 0; }

echo "[rename] 按 apps.tsv 改名"
while IFS='	' read -r old new; do
	# 跳过空行与注释
	case "$old" in ''|\#*) continue ;; esac
	[ -z "$new" ] && continue

	hits=0
	# 1) LuCI 应用菜单
	for f in $(grep -rl "\"title\": *\"$old\"" "$SRC/feeds/luci" --include='*.json' 2>/dev/null); do
		sed -i "s|\"title\": *\"$old\"|\"title\": \"$new\"|g" "$f"
		hits=$((hits + 1))
	done
	# 2) 源码树里自带的包
	for f in $(grep -rl "\"title\": *\"$old\"" "$SRC/package" --include='*.json' 2>/dev/null); do
		sed -i "s|\"title\": *\"$old\"|\"title\": \"$new\"|g" "$f"
		hits=$((hits + 1))
	done

	if [ "$hits" -eq 0 ]; then
		echo "[rename]   '$old' -> '$new'  未匹配（菜单里没这个名字，或写法不同）"
	else
		echo "[rename]   '$old' -> '$new'  改了 $hits 处"
	fi
done < "$TSV"
