-- Aether LuCI — Gool-only, English-only
-- Service control, Gool endpoint config, routing, status

local m = Map("aether", "Aether",
	"Gool (WG-in-WG) censorship circumvention with full-system TUN. " ..
	"Automatic Iranian prefix routing via WAN.")

-- ─── Service Control ──────────────────────────────────────────────
local s = m:section(NamedSection, "main", "aether", "Service Control")
s.addremove = false

local st = s:option(DummyValue, "_state", "Status")
function st.cfgvalue(self, section)
	local st = luci.sys.exec("cat /var/run/aether/state 2>/dev/null"):gsub("\n", "")
	return (st == "") and "down" or st
end

local btn = s:option(Button, "_toggle")
function btn.cfgvalue(self, section)
	local st = luci.sys.exec("cat /var/run/aether/state 2>/dev/null"):gsub("\n", "")
	if st == "up" then
		self.inputtitle = "Disconnect"
		self.inputstyle = "reset"
	else
		self.inputtitle = "Connect"
		self.inputstyle = "apply"
	end
end
function btn.write(self, section)
	local st = luci.sys.exec("cat /var/run/aether/state 2>/dev/null"):gsub("\n", "")
	if st == "up" then
		luci.sys.call("/etc/init.d/aether disable; /etc/init.d/aether stop >/dev/null 2>&1")
	else
		luci.sys.call("/etc/init.d/aether enable; /etc/init.d/aether start >/dev/null 2>&1")
	end
	luci.http.redirect(luci.dispatcher.build_url("admin/services/aether"))
end

local enabled = s:option(Flag, "enabled", "Enable on boot",
	"Start Aether automatically when the router boots")
enabled.rmempty = false

-- ─── Gool (WG-in-WG) Settings ─────────────────────────────────────
local gool = m:section(NamedSection, "main", "aether", "Gool Settings",
	"Endpoint pinning for Gool. Leave empty for auto-scan.")
gool.addremove = false

local wg_peer = gool:option(Value, "wg_peer", "Gool Peer (--wg-peer)",
	"host:port or [ipv6]:port")
wg_peer.placeholder = "auto-scan"

local wiw_outer = gool:option(Value, "wiw_outer", "Gool Outer (--wiw-outer)",
	"Outer WireGuard endpoint")
wiw_outer.placeholder = "auto-scan"

local wiw_inner = gool:option(Value, "wiw_inner", "Gool Inner (--wiw-inner)",
	"Inner WireGuard endpoint")
wiw_inner.placeholder = "auto-scan"

local wg_keepalive = gool:option(Value, "wg_keepalive", "Keepalive (seconds)")
wg_keepalive.default = "25"
wg_keepalive.datatype = "uinteger"

-- ─── VPN Mode ─────────────────────────────────────────────────────
local vm = m:section(NamedSection, "main", "aether", "VPN Mode")
vm.addremove = false

local vf = vm:option(Flag, "vpn_mode", "Full-System VPN (TUN)",
	"Layer hev-socks5-tunnel under aether0 and move default route onto it. " ..
	"Requires kmod-tun and ip-full.")
vf.rmempty = false
vf.default = "1"

local tn = vm:option(Value, "tun_name", "TUN Interface Name")
tn.default = "aether0"

local tm = vm:option(Value, "tun_mtu", "MTU")
tm.default = "1420"
tm.datatype = "range(1280,9000)"

local ba = vm:option(Value, "bind_address", "SOCKS Bind Address")
ba.default = "127.0.0.1:1080"
ba.placeholder = "host:port"

local dns = vm:option(Value, "dns", "Upstream DNS")
dns.default = "1.1.1.1"
dns.placeholder = "1.1.1.1 or 8.8.8.8"

-- ─── Routing ──────────────────────────────────────────────────────
local rt = m:section(NamedSection, "main", "aether", "Routing")
rt.addremove = false

local di = rt:option(Flag, "direct_iran", "Direct Iranian Sites",
	"Send Iranian IP prefixes and domains via WAN instead of tunnel. " ..
	"Uses embedded prefix lists plus domestic domains.")
di.rmempty = false
di.default = "1"

rt:option(TextValue, "route_direct", "Custom Direct Routes",
	"Comma or newline separated: domain, IP/CIDR, port:443, private.").rows = 4

rt:option(TextValue, "route_block", "Custom Blocked Routes",
	"Same format as --route-block.").rows = 4

rt:option(Value, "routes_file", "Custom Rules File",
	"Path to rules file. Takes precedence over embedded lists.").placeholder = "/etc/aether/custom-rules.txt"

-- ─── Scan / Obfuscation ───────────────────────────────────────────
local adv = m:section(NamedSection, "main", "aether", "Scan & Obfuscation")
adv.addremove = false

local sm = adv:option(ListValue, "scan_mode", "Scan Mode")
sm:value("turbo", "Turbo")
sm:value("balanced", "Balanced")
sm:value("thorough", "Thorough")
sm:value("stealth", "Stealth")
sm:value("ironclad", "Ironclad")
sm.default = "balanced"
sm.rmempty = false

local nz = adv:option(ListValue, "noize", "Obfuscation / Noize")
nz:value("balanced", "Balanced")
nz:value("aggressive", "Aggressive")
nz:value("light", "Light")
nz:value("off", "Off")
nz.default = "balanced"

local qr = adv:option(Flag, "quick_reconnect", "Quick Reconnect",
	"Reconnect immediately on connection failure")
qr.default = "1"
qr.rmempty = false

-- ─── Advanced / Maintenance ───────────────────────────────────────
local mgmt = m:section(NamedSection, "main", "aether", "Maintenance")
mgmt.addremove = false

local refresh = mgmt:option(Button, "_refresh_iran", "Refresh Iranian Prefixes")
refresh.inputtitle = "Update Now"
refresh.inputstyle = "reload"
function refresh.write()
	luci.sys.call("/usr/share/aether/refresh-iran-ranges.sh >/var/run/aether/refresh.log 2>&1 &")
end

local view_log = mgmt:option(Button, "_view_log", "View Service Log")
view_log.inputtitle = "Open Log"
view_log.inputstyle = "apply"
function view_log.write()
	luci.http.redirect(luci.dispatcher.build_url("admin/status/log", {filter="aether"}))
end

return m
