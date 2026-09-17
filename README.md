# luci-app-aether (gool-only, English-only)

LuCI app + opkg package + procd service that drives the [Aether](https://github.com/CluvexStudio/Aether) censorship-circumvention core in **gool-only mode** (WG-in-WG) on OpenWrt routers, with full-system TUN via `hev-socks5-tunnel` and one-switch direct routing for Iranian destinations.

## What's in this package

- **Gool protocol only** — no MASQUE, WireGuard, or MIM options in LuCI
- **English-only LuCI** — no translations, simple labels
- **Simple LuCI layout** — Service Control, Gool Settings, VPN Mode, Routing, Scan & Obfuscation, Maintenance
- **Full-system TUN** via hev-socks5-tunnel with policy routing (fwmark bypass for core traffic)
- **Automatic Iranian prefix routing** — 2087 IPv4 + 766 IPv6 prefixes + domestic domains routed via WAN

## Install

```sh
# 1. Install dependencies from official feeds
opkg update
opkg install hev-socks5-tunnel ip-full kmod-tun resolveip ipset dnsmasq-full

# 2. Install the package
opkg install luci-app-aether_*.ipk

# 3. Enable
/etc/init.d/aether enable
```

Then open LuCI → **Services → Aether**, fill in the Gool endpoints (or leave them empty for auto-scan), tick **Direct Iranian sites**, and press **Connect**.

## Build the .ipk

You need the OpenWrt SDK for your target. Example for ipq40xx (armv7):

```sh
# Install the SDK
wget https://downloads.openwrt.org/releases/24.10.0/targets/ipq40xx/generic/openwrt-sdk-24.10.0-ipq40xx-generic_gcc-13.3.0_musl.Linux-x86_64.tar.xz
tar xf openwrt-sdk-*.tar.xz
cd openwrt-sdk-*

# Add this repo as a custom feed
echo "src-link luci-app-aether /path/to/luci-app-aether" >> feeds.conf.default
./scripts/feeds update luci-app-aether
./scripts/feeds install luci-app-aether

# Select and build
make menuconfig   # select luci-app-aether under LuCI → Applications
make package/luci-app-aether/compile
```

The Aether core binary (`aether-linux-armv7-musl.tar.gz`) is downloaded at build time from the CluvexStudio/Aether releases. The hash is pinned in the Makefile — update it if you change AETHER_VERSION.

## Architecture support

| OpenWrt arch | Aether binary |
|---|---|
| aarch64_cortex-a53 | aether-linux-aarch64-musl.tar.gz |
| arm_cortex-a7_neon-vfpv4 | aether-linux-armv7-musl.tar.gz |
| arm_cortex-a9_neon | aether-linux-armv7-musl.tar.gz |
| arm_cortex-a15_neon-vfpv4 | aether-linux-armv7-musl.tar.gz |
| arm_arm926ej-s | aether-linux-armv7-musl.tar.gz |
| x86_64 | aether-linux-x86_64-musl.tar.gz |
| i386_pentium4 | aether-linux-x86_64-musl.tar.gz |
| mips / mipsel | build from source (no upstream binary) |

## Gool endpoints

Gool uses nested WireGuard (WG-in-WG). You need:
- **Gool Peer** (`--wg-peer`) — the inner WG endpoint
- **Gool Outer** (`--wiw-outer`) — the outer WG endpoint
- **Gool Inner** (`--wiw-inner`) — the inner WG endpoint

Leave them empty for auto-scan, or enter them in LuCI for pinned connections.

## Logs

```sh
logread -e aether          # journal
cat /var/run/aether/setup.log   # setup log
cat /var/run/aether/core.log    # core log
cat /var/run/aether/hev.log     # hev log
```

## Refreshing Iran prefix lists

```sh
bash scripts/refresh-iran-ranges.sh   # from repo root, requires curl + python3
```

Done.
