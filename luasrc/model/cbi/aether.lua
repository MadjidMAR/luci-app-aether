-- Aether LuCI — full-featured control panel (multi-protocol, multi-arch)
-- Service control, protocol selection, endpoint config, routing, status

local m = Map("aether", translate("Aether"),
	translate("Multi-protocol censorship circumvention core with full-system TUN support. "..
		"Protocols: Gool (WG-in-WG), MASQUE, WireGuard, MIM. "..
		"Automatic Iranian prefix routing via WAN."))

-- ─── Service Control ──────────────────────────────────────────────
local s = m:section(NamedSection, "main", "aether", translate("Service Control"))
s.addremove = false

local st = s:option(DummyValue, "_state", translate("Status"))
function st.cfgvalue(self, section)
	local st = luci.sys.exec("cat /var/run/aether/state 2>/dev/null"):gsub("\n", "")
	return (st == "") and "down" or st
end

local btn = s:option(Button, "_toggle")
function btn.cfgvalue(self, section)
	local st = luci.sys.exec("cat /var/run/aether/state 2>/dev/null"):gsub("\n", "")
	if st == "up" then
		self.inputtitle = translate("Disconnect")
		self.inputstyle = "reset"
	else
		self.inputtitle = translate("Connect")
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

local enabled = s:option(Flag, "enabled", translate("Enabled"),
	translate("Start Aether automatically on boot"))
enabled.rmempty = false

-- ─── Protocol Selection ───────────────────────────────────────────
local proto = m:section(NamedSection, "main", "aether", translate("Protocol"))
proto.addremove = false

local p = proto:option(ListValue, "protocol", translate("Protocol"))
p:value("gool", translate("Gool (WG-in-WG) — Double WireGuard"))
p:value("masque", translate("MASQUE — HTTP/3 over QUIC"))
p:value("wireguard", translate("WireGuard — Native"))
p:value("mim", translate("MIM — Mimic TLS"))
p.default = "gool"
p.rmempty = false

-- Dynamic scan mode based on protocol
local scan = proto:option(ListValue, "scan_mode", translate("Scan Mode"))
function scan.cfgvalue(self, section)
	local proto = luci.model.uci.cursor():get("aether", "main", "protocol") or "gool"
	local val = self.map:get(section, self.option)
	return val
end
function scan.write(self, section, value)
	self.map:set(section, self.option, value)
end

local ipv = proto:option(ListValue, "ip_version", translate("IP Version"))
ipv:value("both", translate("Dual Stack (IPv4 + IPv6)"))
ipv:value("v4", "IPv4 Only")
ipv:value("v6", "IPv6 Only")
ipv.default = "both"

local noize = proto:option(ListValue, "noize", translate("Obfuscation / Noize"))
noize.default = "balanced"

local qr = proto:option(Flag, "quick_reconnect", translate("Quick Reconnect"),
	translate("Reconnect immediately on connection failure"))
qr.default = "1"
qr.rmempty = false

-- ─── Gool (WG-in-WG) Settings ─────────────────────────────────────
local gool = m:section(NamedSection, "main", "aether", translate("Gool Settings"),
	translate("Endpoint pinning for Gool protocol. Leave empty for auto-scan."))
gool.addremove = false

function gool.cfgvalue(self, section)
	return luci.model.uci.cursor():get("aether", "main", "protocol") == "gool"
end

local wg_peer = gool:option(Value, "wg_peer", translate("Gool Peer (--wg-peer)"),
	translate("Format: host:port or [ipv6]:port"))
wg_peer.placeholder = "auto-scan"

local wiw_outer = gool:option(Value, "wiw_outer", translate("Gool Outer (--wiw-outer)"),
	translate("Outer WireGuard endpoint"))
wiw_outer.placeholder = "auto-scan"

local wiw_inner = gool:option(Value, "wiw_inner", translate("Gool Inner (--wiw-inner)"),
	translate("Inner WireGuard endpoint"))
wiw_inner.placeholder = "auto-scan"

local wg_keepalive = gool:option(Value, "wg_keepalive", translate("Keepalive (seconds)"))
wg_keepalive.default = "25"
wg_keepalive.datatype = "uinteger"

-- ─── MASQUE Settings ──────────────────────────────────────────────
local masque = m:section(NamedSection, "main", "aether", translate("MASQUE Settings"))
masque.addremove = false

function masque.cfgvalue(self, section)
	return luci.model.uci.cursor():get("aether", "main", "protocol") == "masque"
end

local m_host = masque:option(Value, "masque_host", translate("MASQUE Host"),
	translate("Server hostname or IP"))
m_host.placeholder = "required"

local m_port = masque:option(Value, "masque_port", translate("MASQUE Port"))
m_port.default = "443"
m_port.datatype = "port"

local m_pass = masque:option(Value, "masque_password", translate("Password"))
m_pass.password = true

local m_alpn = masque:option(Value, "masque_alpn", translate("ALPN"))
m_alpn.default = "h3"
m_alpn:value("h3", "HTTP/3")
m_alpn:value("h2", "HTTP/2")

-- ─── WireGuard Settings ───────────────────────────────────────────
local wg = m:section(NamedSection, "main", "aether", translate("WireGuard Settings"))
wg.addremove = false

function wg.cfgvalue(self, section)
	return luci.model.uci.cursor():get("aether", "main", "protocol") == "wireguard"
end

local wg_key = wg:option(Value, "wireguard_private_key", translate("Private Key"))
wg_key.password = true

local wg_pub = wg:option(Value, "wireguard_peer_public_key", translate("Peer Public Key"))
wg_pub.password = true

local wg_endpoint = wg:option(Value, "wireguard_endpoint", translate("Endpoint"))
wg_endpoint.placeholder = "host:port"

local wg_allowed = wg:option(Value, "wireguard_allowed_ips", translate("Allowed IPs"))
wg_allowed.default = "0.0.0.0/0,::/0"

local wg_ka = wg:option(Value, "wireguard_keepalive", translate("Keepalive (seconds)"))
wg_ka.default = "25"
wg_ka.datatype = "uinteger"

-- ─── MIM Settings ─────────────────────────────────────────────────
local mim = m:section(NamedSection, "main", "aether", translate("MIM Settings"))
mim.addremove = false

function mim.cfgvalue(self, section)
	return luci.model.uci.cursor():get("aether", "main", "protocol") == "mim"
end

local mim_host = mim:option(Value, "mim_host", translate("MIM Host"))
mim_host.placeholder = "required"

local mim_port = mim:option(Value, "mim_port", translate("MIM Port"))
mim_port.default = "443"
mim_port.datatype = "port"

local mim_pass = mim:option(Value, "mim_password", translate("Password"))
mim_pass.password = true

local mim_obfs = mim:option(ListValue, "mim_obfs", translate("Obfuscation"))
mim_obfs:value("tls", "TLS")
mim_obfs:value("http", "HTTP")
mim_obfs:value("websocket", "WebSocket")

local mim_obfs_host = mim:option(Value, "mim_obfs_host", translate("Obfuscation Host"))

-- ─── VPN Mode ─────────────────────────────────────────────────────
local vm = m:section(NamedSection, "main", "aether", translate("VPN Mode"))
vm.addremove = false

local vf = vm:option(Flag, "vpn_mode", translate("Full-System VPN (TUN)"),
	translate("Layer hev-socks5-tunnel under aether0 and move default route onto it. "..
		"Requires kmod-tun and ip-full."))
vf.rmempty = false
vf.default = "1"

local tn = vm:option(Value, "tun_name", translate("TUN Interface Name"))
tn.default = "aether0"

local tm = vm:option(Value, "tun_mtu", translate("MTU"))
tm.default = "1420"
tm.datatype = "range(1280,9000)"

local ba = vm:option(Value, "bind_address", translate("SOCKS Bind Address"))
ba.default = "127.0.0.1:1080"
ba.placeholder = "host:port"

local dns = vm:option(Value, "dns", translate("Upstream DNS"))
dns.default = "1.1.1.1"
dns.placeholder = "1.1.1.1 or 8.8.8.8"

-- ─── Routing ──────────────────────────────────────────────────────
local rt = m:section(NamedSection, "main", "aether", translate("Routing"))
rt.addremove = false

local di = rt:option(Flag, "direct_iran", translate("Direct Iranian Sites"),
	translate("Send Iranian IP prefixes and domains via WAN instead of tunnel. "..
		"Uses embedded lists (2087 IPv4 + 766 IPv6 prefixes) plus domestic domains."))
di.rmempty = false
di.default = "1"

rt:option(TextValue, "route_direct", translate("Custom Direct Routes"),
	translate("Comma or newline separated: domain, IP/CIDR, port:443, private. "..
		"Same format as core's --route-direct.")).rows = 4

rt:option(TextValue, "route_block", translate("Custom Blocked Routes"),
	translate("Same format as --route-block.")).rows = 4

rt:option(Value, "routes_file", translate("Custom Rules File"),
	translate("Path to [block]/[direct] file. Takes precedence over embedded lists.")).placeholder = "/etc/aether/custom-rules.txt"

-- ─── Advanced / Maintenance ───────────────────────────────────────
local adv = m:section(NamedSection, "main", "aether", translate("Maintenance"))
adv.addremove = false

local refresh = adv:option(Button, "_refresh_iran", translate("Refresh Iranian Prefixes"))
refresh.inputtitle = translate("Update Now")
refresh.inputstyle = "reload"
function refresh.write()
	luci.sys.call("/usr/share/aether/refresh-iran-ranges.sh >/var/run/aether/refresh.log 2>&1 &")
end

local view_log = adv:option(Button, "_view_log", translate("View Service Log"))
view_log.inputtitle = translate("Open Log")
view_log.inputstyle = "apply"
function view_log.write()
	luci.http.redirect(luci.dispatcher.build_url("admin/status/log", {filter="aether"}))
end

return m