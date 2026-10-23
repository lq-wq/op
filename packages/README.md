# packages/ — 仓库内置（vendored）的 LuCI 应用

这些包无法从任何 feed 获取，由 `diy-part1.sh` 在编译前复制进源码树的 `package/` 目录。
其 Makefile 中的 `include ../../luci.mk` 已改为 `include $(TOPDIR)/feeds/luci/luci.mk`
（luci.mk 内部全部基于 `${CURDIR}` 定位文件，复制到任意位置均可正常构建）。

| 目录 | 来源 | 用于分支 | 说明 |
|------|------|----------|------|
| `luci-app-adguardhome/` | openwrt/luci @ openwrt-25.12 | istoreos-24.10 | 24.10 的 luci feed（jjm2473/luci@istoreos-24.10）不带此应用，官方 openwrt/luci 也是 25.12 起才收录，故内置；已将其 `LUCI_EXTRA_DEPENDS` 从 `adguardhome (>=0.107.73-r3)` 放宽为 `>=0.107.57`，以适配 24.10 feed 中的 adguardhome 0.107.57-r1。该应用仅使用 `form.*` / `rpc.declare` / `poll.add` / `fs.exec` 等稳定 API，在 24.10 上可正常运行 |

> openwrt-25.12 分支无需内置任何应用：`luci-app-adguardhome`、`luci-app-dockerman`
> 及 docker 套件均已由官方 feeds 直接提供。

## 更新方法

```bash
# 示例：跟随 openwrt/luci 更新 luci-app-adguardhome
base="https://raw.githubusercontent.com/openwrt/luci/openwrt-25.12/applications/luci-app-adguardhome"
for f in "Makefile" \
         "htdocs/luci-static/resources/view/adguardhome/config.js" \
         "po/lo/adguardhome.po" "po/templates/adguardhome.pot" \
         "root/usr/share/luci/menu.d/luci-app-adguardhome.json" \
         "root/usr/share/rpcd/acl.d/luci-app-adguardhome.json" \
         "root/usr/share/ucitrack/luci-app-adguardhome.json"; do
  mkdir -p "packages/luci-app-adguardhome/$(dirname "$f")"
  curl -sL "$base/$f" -o "packages/luci-app-adguardhome/$f"
done
# 重新修正 include 路径
sed -i 's|^include \.\./\.\./luci\.mk$|include $(TOPDIR)/feeds/luci/luci.mk|' \
  packages/luci-app-adguardhome/Makefile
```
