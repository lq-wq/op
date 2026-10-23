# OpenWrt 软路由定制固件

基于 [iStoreOS](https://github.com/istoreos/istoreos) 源码的 x86_64 软路由定制固件构建项目。
参考 [lq-wq/openwrt](https://github.com/lq-wq/openwrt) 的最简框架组织：**两个 diy 脚本 + 按分支组织的 .config/feeds + GitHub Actions 云编译**。

## 定制项

| 项目 | 值 |
|------|-----|
| 源码 | `github.com/istoreos/istoreos` |
| 可选分支 | `openwrt-25.12`（纯 OpenWrt 25.12）/ `istoreos-24.10`（iStoreOS 定制版） |
| 目标平台 | x86_64 / generic |
| 后台管理地址 | `192.168.6.1` |
| 后台登录密码 | **空**（root 空密码，直接登录） |
| 内核分区 | 64 MB |
| 系统分区 | 2048 MB |
| 预装插件 | AdGuard Home、AppFilter（应用过滤）、DockerMan、MOMO、OpenClash、iStore 应用商店 |
| 主题 | luci-theme-argon |

## 目录结构

```
.
├── .github/workflows/build.yml   # GitHub Actions 云编译（选择分支 → 自动构建）
├── diy-part1.sh                  # feeds 更新后：向源码树添加插件（内置包/git clone）
├── diy-part2.sh                  # defconfig 后：管理 IP、空密码等系统默认值
├── configs/
│   ├── istoreos-24.10/
│   │   ├── .config               # 基于官方 config.seed 定制（960+ 项）
│   │   └── feeds.conf.default    # 官方 iStoreOS feeds + momo/openclash
│   └── openwrt-25.12/
│       ├── .config               # 纯 OpenWrt 25.12 定制配置
│       └── feeds.conf.default    # 官方 feeds + argon/oaf/momo/openclash/store
├── files/etc/uci-defaults/99-custom-settings   # 首次启动兜底（IP/空密码/时区）
├── packages/
│   └── luci-app-adguardhome/     # 24.10 内置应用（该分支 feed 不提供）
└── .research/                    # 调研存档（官方 config.seed 等，不参与构建）
```

## 编译方法

### 方式一：GitHub Actions 云编译（推荐，无需本地环境）

1. 把本项目 push 到自己的 GitHub 仓库；
2. 进入仓库 **Actions → Build OpenWrt Firmware → Run workflow**；
3. 选择分支（`openwrt-25.12` 或 `istoreos-24.10`），开始编译；
4. 完成后在 Artifact 下载固件（`squashfs-combined-efi.img.gz` 等），
   也可勾选 `upload_release` 上传到 Release。

> 仅仓库所有者可触发编译（workflow 内置权限判断）。
> 首次编译约 1~4 小时（24.10 分支含 LLVM 内核工具链，偏慢）。

### 方式二：本地 Linux 编译

需要 Ubuntu 22.04/24.04（或 WSL2/Debian），**Windows 无法直接编译**：

```bash
# 1. 安装依赖
sudo apt update
sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib \
  g++-multilib gettext git libncurses-dev libssl-dev libelf-dev \
  python3-setuptools python3-pyelftools rsync swig unzip zlib1g-dev file wget \
  xz-utils patch pigz dosfstools mtools qemu-utils p7zip-full xxd uglifyjs \
  autoconf automake libtool

# 2. 克隆源码（按需选择分支）
git clone --depth 1 -b openwrt-25.12 https://github.com/istoreos/istoreos openwrt
cd openwrt

# 3. 加载自定义 feeds 并更新
cp ../configs/openwrt-25.12/feeds.conf.default feeds.conf.default
./scripts/feeds update -a && ./scripts/feeds install -a

# 4. 应用 diy 脚本与自定义文件
export BRANCH=openwrt-25.12
../diy-part1.sh
cp -rf ../files/. .
cp ../configs/openwrt-25.12/.config .config
make defconfig
../diy-part2.sh

# 5. 编译（-j 按 CPU 核心数调整，内存建议 ≥ 8GB）
make download -j$(nproc)
make -j$(nproc) V=sc

# 6. 产物在 bin/targets/x86/64/
```

## 定制指南

| 想改什么 | 改哪里 |
|----------|--------|
| 增删插件 | `configs/<分支>/.config` 中增删 `CONFIG_PACKAGE_xxx=y` |
| 管理 IP / 空密码 | `diy-part2.sh`（IP 在 config_generate 中全局替换；shadow 清空密码） |
| 首次启动行为 | `files/etc/uci-defaults/99-custom-settings` |
| 分区大小 | `.config` 中 `CONFIG_TARGET_KERNEL_PARTSIZE` / `CONFIG_TARGET_ROOTFS_PARTSIZE` |
| 插件来源 | `configs/<分支>/feeds.conf.default` 增删 feed |
| 加第三方插件 | `diy-part1.sh` 末尾按示例 `git clone` 到 `package/` |

## 分支对比

| | `openwrt-25.12` | `istoreos-24.10` |
|---|---|---|
| 基础 | 纯上游 OpenWrt 25.12 | iStoreOS 定制版 24.10 |
| 包管理 | apk | opkg/ipk |
| 插件来源 | 官方 feeds + 第三方 | iStoreOS 定制 feeds + 第三方 |
| AdGuardHome 应用 | 官方 luci feed 直供 | 需内置（`packages/`） |
| 适合人群 | 喜欢纯净、追新 | 需要 iStoreOS 生态（iStore 商店等） |

## 刷机与使用

1. 产物为整盘镜像（64M 内核分区 + 2048M 系统分区 ≈ 2.1GB）：
   - `*-squashfs-combined.img.gz`：BIOS 启动
   - `*-squashfs-combined-efi.img.gz`：UEFI 启动（推荐，新机器基本都支持）
2. DD 写入硬盘（`gunzip -c xxx.img.gz | dd of=/dev/sdX bs=1M`）或用 Ventoy/Etcher 等工具；
3. 首次启动后浏览器访问 `http://192.168.6.1`，用户 `root`，密码留空直接登录；
4. 系统分区为只读 squashfs，配置变更保存在 overlay，可安全保留配置升级。

## 常见问题

**Q：应用过滤插件的包名是什么？**
`luci-app-oaf`（来自 jjm2473/OpenAppFilter feed，菜单显示“应用过滤”）。
`luci-app-appfilter` 是 ImmortalWrt 的命名，本项目未采用。

**Q：为什么 istoreos-24.10 要内置 luci-app-adguardhome？**
24.10 的 luci feed（jjm2473/luci@istoreos-24.10）不提供该应用，官方 openwrt/luci
也是 openwrt-25.12 起才收录。内置版本已放宽 adguardhome 版本依赖至 `>=0.107.57`
（适配 24.10 feed 的 0.107.57-r1），应用本身只使用稳定 API，可正常运行。
详见 `packages/README.md`。

**Q：OpenClash 没有核心怎么办？**
固件只装 LuCI 应用，不内置 Clash 内核。启动 OpenClash 后在其界面
“全局设置 → 内核管理 / Check for updates” 一键下载，或手动放入
`/etc/openclash/core/`。

**Q：编译失败/磁盘不足？**
iStoreOS 24.10 构建约需 25GB+ 磁盘；GitHub Actions runner 足够，本地请确保留足空间。
24.10 分支内存建议 ≥ 8GB，不足时用 `make -j2` 降低并行度。

**Q：如何升级到新版固件？**
squashfs 镜像支持“保留配置”升级：LuCI 系统 → 备份/升级 中上传新镜像即可。
