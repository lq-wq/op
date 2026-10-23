#!/bin/bash
# =============================================================================
# diy-part1.sh — 添加第三方插件源码
# 执行时机：feeds 更新之后、.config 加载之前
#
# 运行目录：openwrt 源码树根目录（脚本内相对路径均基于此）
# BRANCH   ：当前编译分支（istoreos-24.10 / openwrt-25.12），
#            由 CI 自动注入；本地构建时需自行 export BRANCH=<分支名>
# =============================================================================

# 本仓库根目录（即本脚本所在目录）
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

# ---- istoreos-24.10：内置 luci-app-adguardhome --------------------------------
# 24.10 的 luci feed（jjm2473/luci@istoreos-24.10）不提供此应用，
# 官方 openwrt/luci 也是 openwrt-25.12 起才收录，故随本仓库内置；
# 其 adguardhome 版本依赖已放宽至 >=0.107.57，适配 24.10 feed 中的 0.107.57-r1。
if [ "${BRANCH:-}" = "istoreos-24.10" ]; then
	rm -rf package/luci-app-adguardhome
	cp -rf "$REPO_ROOT/packages/luci-app-adguardhome" package/
	echo "[diy-part1] 已内置 luci-app-adguardhome（istoreos-24.10 专用）"
fi

# ---- 需要更多第三方插件时，按下面格式追加（git clone 到 package/ 目录）----------
# git clone --depth 1 https://github.com/xxx/luci-app-xxx package/luci-app-xxx

exit 0
