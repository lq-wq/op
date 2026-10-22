# ============================================================
#  自定义插件模板：luci-app-hello
#  照抄这个目录，改目录名/包名/title，就能做出你自己的插件。
#  目录会被 build.sh 拷到源码树的 package/myapps/ 下参与编译。
#
#  最小改动清单：
#   1. 目录名    luci-app-hello  ->  luci-app-你的名字
#   2. LUCI_TITLE 改成你要显示的菜单名
#   3. root/etc/config/hello     -> 你的配置文件名
#   4. menu.d / acl.d 里的 hello -> 你的名字
#   5. htdocs/.../view/hello/hello.js -> 你的页面
# ============================================================

include $(TOPDIR)/rules.mk

LUCI_TITLE:=Hello 演示
LUCI_DESCRIPTION:=最小可用的 LuCI 插件骨架，用来照抄改成自己的插件
LUCI_PKGARCH:=all
LUCI_DEPENDS:=
PKG_LICENSE:=MIT
PKG_MAINTAINER:=you <you@example.com>

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
