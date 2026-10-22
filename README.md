# iStoreOS 自用固件框架（x86_64）

基于 [iStoreOS `openwrt-25.12`](https://github.com/istoreos/istoreos/tree/openwrt-25.12) 源码.

## 三步出固件（推荐：GitHub 云端编译）

1. **改 `device.conf`**（密码留空就是空密码）。想预装软件就编辑 `configs/packages.list`。
2. **把这个目录推到你自己的 GitHub 仓库**（私有仓库也行）：
   ```bash
   git init && git add . && git commit -m "my router"
   git remote add origin https://github.com/你的用户名/你的仓库.git
   git push -u origin main
   ```
3. 打开仓库 → **Actions** → 左侧 `build-firmware` → **Run workflow**。
   等 1~3 小时（首次），完成后在本次运行页面底部下载 `firmware-xxx` 压缩包，
   里面就是 `*.img.gz`。

> 免费额度：公开仓库 Actions 不扣分钟数；私有仓库每月 2000 分钟，够编译 2~3 次。
> 想省时间：源码和 `dl` 目录已被缓存，第二次编译会快很多。

### 网口分配规则（`MODE=router` 时）

| 探测到的物理口数 | 结果 |
| --- | --- |
| 1 个 | 自动退化为单臂旁路由（LAN=192.168.6.1，关 DHCP，开 Masquerade） |
| 2 个及以上 | 第一个口做 WAN（DHCP/PPPoE），其余桥接成 `br-lan` |
| 0 个 | 不动配置，保留镜像默认（说明网卡驱动没覆盖，见下方「排错」） |

想自己指定口，把 `PORT_POLICY` 改成 `manual`，再填 `MANUAL_WAN_PORT` / `MANUAL_LAN_PORTS`。

## 预装插件清单（本次加入的 8 个）

| 插件 | 来源 feed | 说明 |
| --- | --- | --- |
| `luci-app-oaf` 应用过滤 | oaf（destan19/OpenAppFilter） | 含内核模块；**对新内核兼容性一般，编译失败就把 packages.list / feeds.conf 里相关行注释掉** |
| `luci-app-dockerman` | 官方 luci feed | 需 `docker` + `dockerd`（已一起加入）；体积大、首次编译明显变慢 |
| `luci-theme-kucat` | jerrykuku feed | 已设为默认主题（`THEME="kucat"`） |
| `luci-theme-argon` | jerrykuku feed | 备用主题，LuCI 里可切换 |
| `luci-app-adguardhome` + `adguardhome` | kenzok8 feed | **AdGuardHome 核心随包编译进固件**，开箱即用；Go 编译会增加 10-20 分钟 |
| `luci-app-openclash` | vernesong feed | 核心由首启脚本 `50-openclash-core` 自动下载到 `/etc/openclash/core/clash_meta`；没网时下次开机重试 |
| `luci-app-upnp` | 官方 luci feed | 含 miniupnpd |
| `luci-app-store` iStore | linkease/istore feed | iStore 应用商店，装好后从商店加软件最方便 |

插件语言包已一并加入（`luci-i18n-*-zh-cn`）。插件有冲突或编译失败时，
看 Actions 日志里的包名，去 `configs/packages.list` 注释对应行再编即可。

## 改东西速查表

| 想改 | 改哪里 |
| --- | --- |
| 主机名 / 品牌名 / 版本 | `device.conf` → `DEVICE_NAME` `BRAND_NAME` `BRAND_VERSION` |
| 个性签名（编译者） | `device.conf` → `BUILDER_NAME`（日期编译时自动生成） |
| 默认主题 | `device.conf` → `THEME`（kucat / argon / bootstrap） |
| 带宽档位（流卸载开关） | `device.conf` → `HOME_BANDWIDTH`、`HW_OFFLOAD` |
| 管理 IP / DHCP 段 | `device.conf` → `LAN_IP` `LAN_DHCP_START/END` |
| 密码 | `device.conf` → `ROOT_PASSWORD`（留空=无密码） |
| 主路由 / 旁路由 | `device.conf` → `MODE`（router / bypass） |
| 内核 / 系统分区大小 | `device.conf` → `KERNEL_SIZE_MB` / `ROOTFS_SIZE_MB` |
| 拨号账号 | `device.conf` → `WAN_PROTO="pppoe"` + `PPPOE_USER/PASS` |
| 预装软件 | `configs/packages.list` 加一行 |
| 软件显示名 | `brand/apps.tsv` 加一行「英文原名 + Tab + 新名字」 |
| 首启行为 | `files/etc/uci-defaults/` 下加一个 `数字-名字` 脚本（记得 `chmod 755`） |
| 自己的插件 | 复制 `packages/luci-app-hello`，改目录名和 `LUCI_TITLE` |

## 排错

- **编译报 `Package xxx is missing`**：`configs/packages.list` 里那个包名不在源里，注释掉再编。
  重点排查：`luci-app-oaf`（内核兼容性）、第三方 feed 拉取失败（GitHub 抽风，重跑一次 Actions）。
- **编译时间变长**：`adguardhome`（Go 编译）和 `dockerd` 是大头，属正常，首次约 2-4 小时。
- **OpenClash 没有核心**：看 `/etc/.openclash-core.log`；一直失败就手动在插件页面里下载 Meta 核心。
- **菜单名没变**：`brand/apps.tsv` 左边必须是 menu.d 里的英文原名，大小写敏感；编译日志搜 `[rename]` 看是否匹配。
- **首启配置没生效**：检查脚本是否有可执行权限（`ls -l /etc/uci-defaults/`），或看 `/etc/.net-autodetect.log`。
- **网口只识别到一个**：可能是 2.5G 网卡（RTL8125/8126）或 USB 网卡，确认 `x86_64.defconfig` 里对应 `kmod-*` 已开。
- **SSH 空密码被拒**：部分 dropbear 版本不允许空密码登录，Web 后台仍可空密码进；
  需要 SSH 就在 LuCI 终端执行 `passwd root` 设一个密码。
- **开启流卸载后部分功能异常**（如某些加速/游戏 NAT 类型）：LuCI → 防火墙里关掉
  「流量分载/硬件流卸载」，或把 `HW_OFFLOAD` 改回 `0` 重编。

