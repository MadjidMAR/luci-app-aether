#!/bin/sh
# Aether TUN finish task (gool-only) — runs DETACHED (setsid) after start_service

. /lib/functions.sh
. /usr/share/aether/setup-lib.sh

# Restart core if not running
restart_core() {
	if [ -f "$CORE_PID" ]; then
		read -r CPID <"$CORE_PID" 2>/dev/null
		if [ -n "$CPID" ] && [ -d "/proc/$CPID" ]; then
			return 0
		fi
	fi
	log "Core not running — restarting"
	kill_finish 2>/dev/null
	for p in $(pidof aether 2>/dev/null); do kill "$p" 2>/dev/null; done
	sleep 1
	setsid "$PROG_AETHER" $ARGS >>"$RUN_DIR/core.log" 2>&1 < /dev/null &
	echo $! >"$CORE_PID"
	log "Core restarted (PID: $!)"
	sleep 2
}

# Wait for SOCKS port with exponential backoff
wait_for_socks() {
	local host="$1" port="$2" timeout="${3:-120}"
	local elapsed=0 interval=1 max_interval=10

	log "Waiting for SOCKS $host:$port (timeout: ${timeout}s)..."
	while [ $elapsed -lt $timeout ]; do
		if nc -z "$host" "$port" 2>/dev/null; then
			log "SOCKS $host:$port is ready"
			return 0
		fi
		sleep $interval
		elapsed=$((elapsed + interval))
		interval=$((interval < max_interval ? interval + 1 : max_interval))
	done
	log "Timeout waiting for SOCKS $host:$port"
	return 1
}

# Main loop
while true; do
	config_load aether
	section_get enabled enabled 0
	[ "$enabled" = "1" ] || { rm -f "$FINISH_PID"; exit 0; }

	config_load aether
	load_options
	echo $$ >"$FINISH_PID"

	restart_core

	wait_for_socks "$SOCKS_HOST" "$SOCKS_PORT" 120 || {
		echo "down" >"$RUN_DIR/state"
		rm -f "$FINISH_PID"
		sleep 10
		continue
	}

	config_load aether
	section_get enabled enabled 0
	[ "$enabled" = "1" ] || { rm -f "$FINISH_PID"; exit 0; }

	config_load aether
	load_options

	# Start hev-socks5-tunnel if VPN mode enabled
	if [ "$vpn_mode" = "1" ]; then
		[ -x "$PROG_HEV" ] || { log "ERROR: $PROG_HEV missing"; echo "down" >"$RUN_DIR/state"; rm -f "$FINISH_PID"; sleep 10; continue; }
		
		gen_hev_conf

		# Try to register with procd for managed lifecycle
		if . /lib/functions/procd.sh 2>/dev/null && procd_open_service aether /etc/init.d/aether 2>/dev/null; then
			procd_open_instance hev
			procd_set_param command "$PROG_HEV" "$HEV_CONF"
			procd_set_param respawn 3600 5 5
			procd_set_param stdout 1
			procd_set_param stderr 1
			procd_close_instance
			if procd_close_service add 2>/dev/null; then
				log "hev-socks5-tunnel registered with procd"
			else
				setsid "$PROG_HEV" "$HEV_CONF" >>"$RUN_DIR/hev.log" 2>&1 < /dev/null &
				echo $! >"$HEV_PID"
				log "hev started detached (procd add failed)"
			fi
		else
			setsid "$PROG_HEV" "$HEV_CONF" >>"$RUN_DIR/hev.log" 2>&1 < /dev/null &
			echo $! >"$HEV_PID"
			log "hev started detached (no procd)"
		fi

		wait_for "TUN $tun_name" 30 "ip link show $tun_name" || {
			echo "down" >"$RUN_DIR/state"
			rm -f "$FINISH_PID"
			sleep 10
			continue
		}

		net_up || {
			echo "down" >"$RUN_DIR/state"
			rm -f "$FINISH_PID"
			sleep 10
			continue
		}
	fi

	date -u +%FT%TZ >"$RUN_DIR/uptime"
	echo "up" >"$RUN_DIR/state"
	log "UP (tun=$([ "$vpn_mode" = "1" ] && echo "$tun_name" || echo "proxy-only"), protocol=$protocol)"
	rm -f "$FINISH_PID"

	# Health check loop - monitor core and TUN
	while true; do
		sleep 30
		
		config_load aether
		section_get enabled enabled 0
		[ "$enabled" = "1" ] || { exit 0; }

		# Check core
		if [ -f "$CORE_PID" ]; then
			read -r CPID <"$CORE_PID" 2>/dev/null
			if [ -z "$CPID" ] || [ ! -d "/proc/$CPID" ]; then
				log "Core died, will restart"
				break
			fi
		fi

		# Check TUN if VPN mode
		if [ "$vpn_mode" = "1" ] && ! ip link show "$tun_name" >/dev/null 2>&1; then
			log "TUN $tun_name disappeared, will restart"
			break
		fi

		# Check hev-socks5-tunnel
		if [ "$vpn_mode" = "1" ] && [ -f "$HEV_PID" ]; then
			read -r HPID <"$HEV_PID" 2>/dev/null
			if [ -n "$HPID" ] && [ ! -d "/proc/$HPID" ]; then
				log "hev-socks5-tunnel died, will restart"
				break
			fi
		fi
	done

	# Clean up before restart
	net_down 2>/dev/null
	for p in $(pidof hev-socks5-tunnel 2>/dev/null); do kill "$p" 2>/dev/null; done
	sleep 2
done