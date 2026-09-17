#!/bin/sh
# luci-app-aether installation helper script
# Usage: ./install.sh [--no-deps] [--arch ARCH]

set -eu

NO_DEPS=0
ARCH=""

while [ $# -gt 0 ]; do
	case "$1" in
		--no-deps) NO_DEPS=1 ;;
		--arch) shift; ARCH="$1" ;;
		*) echo "Unknown option: $1" >&2; exit 1 ;;
	esac
	shift
done

# Detect architecture if not provided
if [ -z "$ARCH" ]; then
	ARCH=$(opkg print-architecture 2>/dev/null | head -1 | awk '{print $2}')
	echo "Detected architecture: $ARCH"
fi

# Map OpenWrt arch to package arch
case "$ARCH" in
	aarch64*|cortex-a53*) PKGARCH="aarch64_cortex-a53" ;;
	arm_cortex-a7*|ipq40xx*) PKGARCH="arm_cortex-a7_neon-vfpv4" ;;
	arm_cortex-a9*) PKGARCH="arm_cortex-a9_neon" ;;
	arm_cortex-a15*) PKGARCH="arm_cortex-a15_neon-vfpv4" ;;
	arm_arm926ej-s*) PKGARCH="arm_arm926ej-s" ;;
	mips_24kc*) PKGARCH="mips_24kc" ;;
	mipsel_24kc*) PKGARCH="mipsel_24kc" ;;
	mips_1004kc_dsp*) PKGARCH="mips_1004kc_dsp" ;;
	mipsel_1004kc_dsp*) PKGARCH="mipsel_1004kc_dsp" ;;
	x86_64*) PKGARCH="x86_64" ;;
	i386*|pentium4*) PKGARCH="i386_pentium4" ;;
	*)
		echo "Unsupported architecture: $ARCH"
		echo "Supported: aarch64, arm_cortex-a7, arm_cortex-a9, arm_cortex-a15, arm_arm926ej-s, mips_24kc, mipsel_24kc, x86_64, i386_pentium4"
		exit 1
		;;
esac

echo "Package architecture: $PKGARCH"

# Check OpenWrt version
VERSION=$(cat /etc/openwrt_release 2>/dev/null | grep DISTRIB_RELEASE | cut -d"'" -f2)
echo "OpenWrt version: $VERSION"

# Install dependencies
if [ $NO_DEPS -eq 0 ]; then
	echo "Installing dependencies..."
	opkg update
	opkg install hev-socks5-tunnel ip-full kmod-tun resolveip ipset dnsmasq-full
fi

# Find and install IPK
IPK="luci-app-aether_*_${PKGARCH}.ipk"
if ls $IPK 1>/dev/null 2>&1; then
	echo "Installing local package: $IPK"
	opkg install $IPK
else
	echo "No local package found for $PKGARCH"
	echo "Download from: https://github.com/Omarchy71/luci-app-aether/releases"
	echo "Looking for: luci-app-aether_*_${PKGARCH}.ipk"
	exit 1
fi

# Enable and start
echo "Enabling and starting aether service..."
/etc/init.d/aether enable
/etc/init.d/aether start

echo ""
echo "Installation complete!"
echo "Open LuCI -> Services -> Aether to configure."
echo ""
echo "Logs: logread -e aether"
echo "Status: /etc/init.d/aether status"