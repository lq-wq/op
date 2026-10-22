# iStoreOS 自用固件框架（x86_64 / N100）

基于 [iStoreOS `openwrt-25.12`](https://github.com/istoreos/istoreos/tree/openwrt-25.12) 源码，
给你一套「改一个文件 → 云端出固件」的骨架。不需要写代码。

## 它能做什么

| 你的需求 | 框架里对应的东西 |
| --- | --- |
| 自动识别有几个网口 | `files/etc/uci-defaults/20-net-autodetect` |
| SSD 存储可用 | `device.conf` 的 `KERNEL_SIZE_MB=128` / `ROOTFS_SIZE_MB=2048` + 可选 `EXTEND_ROOTFS=1` |
| 管理地址 192.168.6.1、密码为空 | `device.conf` 的 `LAN_IP` / `ROOT_PASSWORD=""` |
| 个性签名（编译者 + 自动日期） | `device.conf` 的 `BUILDER_NAME`；日期在编译时自动生成，打进登录横幅和 LuCI 页脚 |
| 家庭千兆带宽 | `device.conf` 的 `HOME_BANDWIDTH=1000` → 首启自动开流卸载 + 多核调度（`21-bandwidth`） |
| 方便加软件 | `configs/packages.list`，一行一个包 |
| 改设备名 | `device.conf` 的 `DEVICE_NAME` / `BRAND_NAME` |
| 改软件显示名 | `brand/apps.tsv`，一行一个改名 |
| 默认主题 | `device.conf` 的 `THEME`（kucat / argon / bootstrap） |

## 目录结构

```
istoreos-fw/
├─ device.conf              ★ 唯一要改的文件（设备名/IP/密码/网口/存储/签名/主题）
├─ configs/
│  ├─ x86_64.defconfig      目标平台与内核驱动（一般不用动）
│  └─ packages.list         ★ 要预装什么软件，一行一个
├─ brand/apps.tsv           ★ 软件改名映射（LuCI 里显示的名字）
├─ files/                    打进固件的 overlay（改完会替换系统里的同名文件）
│  └─ etc/
│     ├─ device-profile.tmpl      编译时生成，运行时只读的参数表
│     └─ uci-defaults/            首次启动自动执行的脚本（跑完自动删）
│        ├─ 10-brand              主机名、时区、语言、登录横幅（含编译者签名）
│        ├─ 11-theme              启用默认主题（kucat/argon）
│        ├─ 20-net-autodetect     网口自动识别 + 生成网络配置
│        ├─ 21-bandwidth          千兆带宽：流卸载 + 多核调度
│        ├─ 30-ssd-extend         SSD 扩容（可选，默认关闭）
│        ├─ 40-root-nopasswd      空密码 / 设密码
│        └─ 50-openclash-core     自动下载 OpenClash Meta 核心（有网就装）
├─ packages/                 你自己的插件（luci-app-hello 是模板，照抄改名）
├─ scripts/
│  ├─ render-files.sh        把 device.conf 填进 files/ 模板
│  └─ rename-apps.sh         编译前按 apps.tsv 改菜单标题
├─ feeds.conf                额外 feed（iStore 商店等）
├─ build.sh                  一键编译
└─ .github/workflows/build.yml   GitHub 云端自动编译
```

## 三步出固件（推荐：GitHub 云端编译，你自己的电脑不用装 Linux）

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

### 本地编译（有 WSL / Ubuntu 才用）

```bash
sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
  gettext git libncurses5-dev libssl-dev python3-distutils rsync unzip zlib1g-dev file wget
bash build.sh          # 产物在 .src/istoreos/bin/targets/x86/64/
```

## 刷机与首启会发生什么

1. Etcher 把 `*.img.gz` 写进 U 盘 → 机器从 U 盘启动 → 按上一篇指南把它 dd 到内置 SSD。
2. **首次启动**按顺序自动执行七个脚本（各执行一次，成功即自删）：
   - `10-brand`：主机名 = `DEVICE_NAME`，时区 +8，LuCI 中文，登录横幅 = 品牌名 + **编译者签名 + 编译日期**
   - `11-theme`：按 `THEME` 启用 kucat / argon 主题（主题没装上就自动跳过，不会白屏）
   - `20-net-autodetect`：探测物理网口数量 → 生成 WAN/LAN、DHCP、防火墙
   - `21-bandwidth`：`HOME_BANDWIDTH>=500` 时自动开启软件流卸载（N100 跑千兆很轻松）
   - `30-ssd-extend`：仅在 `EXTEND_ROOTFS=1` 时动分区，会重启一次
   - `40-root-nopasswd`：`ROOT_PASSWORD` 为空 → root 无密码；有值 → 设成该密码
   - `50-openclash-core`：给 OpenClash 自动下载 Meta(mihomo) 核心，失败下次启动重试
3. 浏览器开 **http://192.168.6.1**，密码留空直接进。
4. 想确认网口探测结果：SSH 或 LuCI 终端里 `cat /etc/portmap.txt`，日志在 `/etc/.net-autodetect.log`。

### 网口分配规则（`MODE=router` 时）

| 探测到的物理口数 | 结果 |
| --- | --- |
| 1 个 | 自动退化为单臂旁路由（LAN=192.168.6.1，关 DHCP，开 Masquerade） |
| 2 个及以上 | 第一个口做 WAN（DHCP/PPPoE），其余桥接成 `br-lan` |
| 0 个 | 不动配置，保留镜像默认（说明网卡驱动没覆盖，见下方「排错」） |

想自己指定口，把 `PORT_POLICY` 改成 `manual`，再填 `MANUAL_WAN_PORT` / `MANUAL_LAN_PORTS`。

## 存储说明（SSD）

- 镜像分区由 `device.conf` 决定：**内核 128MB / 系统 2048MB**。
  系统分区就是 overlay（装软件/Docker 的空间），开箱约 2GB 可用，不需要在机器上动分区表。
- 想一次吃满整块 SSD：把 `ROOTFS_SIZE_MB` 改成 SSD 容量（如 `60000`）**或**
  设 `EXTEND_ROOTFS="1"` 让首启自动扩分区。
  - 前者镜像文件会变大（dd 更慢，gz 下载体积增加不多），但完全可控。
  - 后者不动镜像体积，首启自动 `parted resizepart` + 重启，属于进阶功能，建议先在备用盘上验证。
- 扩容失败的补救（LuCI 终端里执行，把 `nvme0n1` 换成你的盘）：
  ```sh
  parted -s /dev/nvme0n1 resizepart 2 100%
  reboot
  # 重启后确认：df -h /overlay
  ```

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

## 已知限制（说实话）

- `30-ssd-extend` 的自动扩容走的是 `parted resizepart` + 重启，**没有在你的机器上实测过**，
  建议先用 `ROOTFS_SIZE_MB` 方案；开这个开关前确认盘里没有要留的数据。
- 空密码是「纯内网自用」的取舍，不要把管理端口映射到公网。
- 改名只覆盖 LuCI 菜单标题；软件包列表里的「包名/描述」来自包自身，不在本框架范围内。
