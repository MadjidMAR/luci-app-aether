include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-aether
PKG_VERSION:=0.3.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Madjid <omarchy7117@atomicmail.io>

# Aether core version (must match upstream release)
AETHER_VERSION:=v2.0.0
AETHER_RELEASE_URL:=https://github.com/CluvexStudio/Aether/releases/download/$(AETHER_VERSION)

# Architecture mapping: OpenWrt ARCH -> Aether binary + PKGARCH
# We support musl libc variants (standard on OpenWrt)
# MIPS: no upstream binary — build from source or remove target
define AetherArchMap
  aarch64:PKG_SOURCE:=aether-linux-aarch64-musl.tar.gz
  aarch64:PKG_HASH:=839316b7ac3571d32bf2c17311a01cfa10cfef738c9b14ce0c485cef0888d3
  aarch64:PKGARCH:=aarch64_cortex-a53

  arm_cortex-a7:PKG_SOURCE:=aether-linux-armv7-musl.tar.gz
  arm_cortex-a7:PKG_HASH:=b2373438508f224400683c69bb50d9c935d28de514f1fde06e701cee58be878a
  arm_cortex-a7:PKGARCH:=arm_cortex-a7_neon-vfpv4

  arm_cortex-a9:PKG_SOURCE:=aether-linux-armv7-musl.tar.gz
  arm_cortex-a9:PKG_HASH:=b2373438508f224400683c69bb50d9c935d28de514f1fde06e701cee58be878a
  arm_cortex-a9:PKGARCH:=arm_cortex-a9_neon

  arm_cortex-a15:PKG_SOURCE:=aether-linux-armv7-musl.tar.gz
  arm_cortex-a15:PKG_HASH:=b2373438508f224400683c69bb50d9c935d28de514f1fde06e701cee58be878a
  arm_cortex-a15:PKGARCH:=arm_cortex-a15_neon-vfpv4

  arm_arm926ej-s:PKG_SOURCE:=aether-linux-armv7-musl.tar.gz
  arm_arm926ej-s:PKG_HASH:=b2373438508f224400683c69bb50d9c935d28de514f1fde06e701cee58be878a
  arm_arm926ej-s:PKGARCH:=arm_arm926ej-s

  mips_24kc:PKG_SOURCE:=aether-linux-mips-musl.tar.gz
  mips_24kc:PKG_HASH:=BUILD_FROM_SOURCE
  mips_24kc:PKGARCH:=mips_24kc

  mipsel_24kc:PKG_SOURCE:=aether-linux-mipsel-musl.tar.gz
  mipsel_24kc:PKG_HASH:=BUILD_FROM_SOURCE
  mipsel_24kc:PKGARCH:=mipsel_24kc

  mips_1004kc_dsp:PKG_SOURCE:=aether-linux-mips-musl.tar.gz
  mips_1004kc_dsp:PKG_HASH:=BUILD_FROM_SOURCE
  mips_1004kc_dsp:PKGARCH:=mips_1004kc_dsp

  mipsel_1004kc_dsp:PKG_SOURCE:=aether-linux-mipsel-musl.tar.gz
  mipsel_1004kc_dsp:PKG_HASH:=BUILD_FROM_SOURCE
  mipsel_1004kc_dsp:PKGARCH:=mipsel_1004kc_dsp

  x86_64:PKG_SOURCE:=aether-linux-x86_64-musl.tar.gz
  x86_64:PKG_HASH:=SKIP
  x86_64:PKGARCH:=x86_64

  i386_pentium4:PKG_SOURCE:=aether-linux-x86_64-musl.tar.gz
  i386_pentium4:PKG_HASH:=SKIP
  i386_pentium4:PKGARCH:=i386_pentium4
endef

# Auto-detect architecture and set variables
ARCH:=$(ARCH)
ifneq ($(filter aarch64 arm_cortex-a7 arm_cortex-a9 arm_cortex-a15 arm_arm926ej-s mips_24kc mipsel_24kc mips_1004kc_dsp mipsel_1004kc_dsp x86_64 i386_pentium4),$(ARCH))
  $(error Unsupported architecture: $(ARCH). Supported: aarch64, arm_cortex-a7, arm_cortex-a9, arm_cortex-a15, arm_arm926ej-s, mips_24kc, mipsel_24kc, mips_1004kc_dsp, mipsel_1004kc_dsp, x86_64, i386_pentium4)
endif

# Extract architecture-specific values
PKG_SOURCE:=$(shell echo '$(AetherArchMap)' | grep '^$(ARCH):PKG_SOURCE:' | cut -d: -f3)
PKG_HASH:=$(shell echo '$(AetherArchMap)' | grep '^$(ARCH):PKG_HASH:' | cut -d: -f3)
PKGARCH:=$(shell echo '$(AetherArchMap)' | grep '^$(ARCH):PKGARCH:' | cut -d: -f3)

PKG_SOURCE_URL:=$(AETHER_RELEASE_URL)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)-$(ARCH)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-aether
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for Aether censorship circumvention (multi-arch)
  DEPENDS:=+luci-base +luci-compat +hev-socks5-tunnel +ip-full +kmod-tun +resolveip +ipset +dnsmasq-full
  PKGARCH:=$(PKGARCH)
endef

define Package/luci-app-aether/description
  Multi-architecture LuCI app + procd service for the Aether censorship-circumvention
  core on OpenWrt routers. Supports gool (WG-in-WG), MASQUE, WireGuard, and mim protocols
  with full-system TUN via hev-socks5-tunnel, automatic Iranian prefix routing,
  and per-device policy routing via fwmarks/nftables.
  
  Supported architectures: aarch64, armv7 (cortex-a7/a9/a15), mips/mipsel, x86_64
endef

define Build/Prepare
	$(if $(filter BUILD_FROM_SOURCE,$(PKG_HASH)),\
		$(error MIPS builds require compiling the Aether core from source. See README.md for instructions.),\
		mkdir -p $(PKG_BUILD_DIR)\
		tar -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) 2>/dev/null || \
		tar -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1 2>/dev/null || true\
		chmod +x $(PKG_BUILD_DIR)/aether 2>/dev/null || true\
	)

define Build/Compile
	# No compilation needed - using prebuilt binary
	true
endef

define Package/luci-app-aether/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/aether $(1)/usr/sbin/aether

	$(INSTALL_DIR) $(1)/usr/share/aether
	$(CP) ./root/usr/share/aether/* $(1)/usr/share/aether/
	$(INSTALL_BIN) ./scripts/refresh-iran-ranges.sh $(1)/usr/share/aether/

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/aether $(1)/etc/init.d/aether

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/aether $(1)/etc/config/aether

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/aether.lua $(1)/usr/lib/lua/luci/controller/aether.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/model/cbi/aether.lua $(1)/usr/lib/lua/luci/model/cbi/aether.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/aether
	$(INSTALL_DATA) ./luasrc/view/aether/* $(1)/usr/lib/lua/luci/view/aether/ 2>/dev/null || true
endef

define Package/luci-app-aether/postinst
#!/bin/sh
# Enable service on install
/etc/init.d/aether enable 2>/dev/null || true
exit 0
endef

define Package/luci-app-aether/prerm
#!/bin/sh
# Stop and disable on removal
/etc/init.d/aether stop 2>/dev/null || true
/etc/init.d/aether disable 2>/dev/null || true
exit 0
endef

$(eval $(call BuildPackage,luci-app-aether))