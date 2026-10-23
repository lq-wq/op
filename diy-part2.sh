#!/bin/bash
# =============================================================================
# diy-part2.sh — 固件系统定制
# 执行时机：.config 加载并 make defconfig 之后
#
# 运行目录：openwrt 源码树根目录
# 说明：插件选择、分区大小等已全部写在 configs/<分支>/.config 中，
#       本脚本只负责修改源码树里的默认值（.config 表达不了的部分）。
# =============================================================================

# ---- 1) 后台管理地址 → 192.168.6.1 ---------------------------------------------
# 修改默认网络配置生成脚本：首次启动生成 /etc/config/network 时，
# LAN 默认 IP 即为 192.168.6.1。
# 配套机制：
#   - .config 中 CONFIG_TARGET_PREINIT_IP="192.168.6.1"：配置丢失/恢复模式下
#     预启动网络地址同样是 192.168.6.1；
#   - files/etc/uci-defaults/99-custom-settings：首次启动时再兜底一次。
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate \
	&& echo "[diy-part2] 默认管理地址已设为 192.168.6.1"

# ---- 2) root 空密码 --------------------------------------------------------------
# 清空 /etc/shadow 中 root 的密码字段：后台与 SSH 均可用空密码直接登录。
# （两分支 base-files 默认即为空密码，此处兜底以防上游默认值变化；
#   首次启动时 uci-defaults 还会再确保一次）
sed -i 's/^root:[^:]*:/root::/' package/base-files/files/etc/shadow \
	&& echo "[diy-part2] root 密码已清空（空密码登录）"

exit 0
