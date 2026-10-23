# .research/ — 调研资料存档

本目录保存项目制作过程中的调研资料，供追溯与后续维护参考，**不参与编译**。

## 官方构建配置存档

| 文件 | 来源 | 说明 |
|------|------|------|
| `istoreos-24.10-config.seed` | fw.koolcenter.com（iStoreOS 官方 24.10 x86_64 构建配置） | `configs/istoreos-24.10.config` 的基线 |
| `istoreos-25.12-config.seed` | fw.koolcenter.com（iStoreOS 官方 25.12 x86_64 构建配置） | 参考（本项目 25.12 走纯 OpenWrt 路线，未采用 iStoreOS 25.12 的 jjm2473 软件源） |
| `istoreos-24.10-feeds.conf` | fw.koolcenter.com | 官方构建附加 feeds |
| `istoreos-25.12-feeds.conf` | fw.koolcenter.com | 同上（两分支一致） |

## 关键调研结论

1. **分区**：x86_64 combined 镜像由 `gen_image_generic.sh` 直接按
   `CONFIG_TARGET_KERNEL_PARTSIZE` / `CONFIG_TARGET_ROOTFS_PARTSIZE` 生成
   「内核分区 + 系统分区」，改 .config 即可，无需打补丁。
2. **默认 LAN IP**：官方机制为 `CONFIG_TARGET_DEFAULT_LAN_IP_FROM_PREINIT=y` +
   `CONFIG_TARGET_PREINIT_IP="192.168.6.1"`（base-files 构建期生成
   `/etc/board.d/99-lan-ip`，首次启动 `config_generate` 时生效）；
   本项目另加 `files/etc/uci-defaults/99-custom-settings` 兜底。
   config_generate 在 preinit 阶段执行，早于 uci-defaults，顺序无冲突。
3. **root 密码**：上游 OpenWrt 默认 `/etc/shadow` 中 root 即为空密码；
   首次启动 `passwd -d root` 可确保空密码登录。
4. **argon 主题**：官方 OpenWrt luci feed 不含 argon，来自
   jjm2473/openwrt-third（git 子模块，`scripts/feeds` 会递归初始化）。
5. **adguardhome**：24.10 的 jjm2473/luci fork 无 `luci-app-adguardhome`，
   且 feed 中 adguardhome 为 0.107.57 < 官方 25.12 应用要求的 0.107.73-r3，
   故 vendoring 并放宽版本依赖（见 `packages/README.md`）。
6. **dockerman**：纯 OpenWrt 25.12 的 luci feed 无此应用，但官方 packages feed
   已提供 docker/dockerd/containerd/runc/docker-compose，故只需 vendoring
   LuCI 应用本身（luci.mk 基于 `${CURDIR}` 定位，复制到 `package/` 即可构建）。
7. **appfilter 包名**：iStoreOS/OpenWrt 生态正式包名为 `luci-app-oaf`
   （jjm2473/OpenAppFilter dev7），非 `luci-app-appfilter`。
8. **i18n**：上游 luci feed 与 jjm2473 fork 均无 Config.in（包符号由构建系统
   自动生成），也无 `LUCI_LANG_*` kconfig 符号，中文需显式启用
   `CONFIG_PACKAGE_luci-i18n-*-zh-cn=y`（24.10 官方 seed 即此做法）。
