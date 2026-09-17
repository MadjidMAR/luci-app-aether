#!/usr/bin/env bash
# Refresh the embedded Iranian prefix lists from the daily-aggregated source.
# Same source + validation as Aethery's refresh script.
# Run from the repo root:  bash scripts/refresh-iran-ranges.sh
set -euo pipefail

BASE="https://github.com/Cod3ByAmir/iran-ip-ranges/releases/latest/download"
OUT="luci-app-aether/root/usr/share/aether"

mkdir -p "$OUT"

echo "Fetching Iranian IPv4 prefixes..."
curl -sSL --max-time 120 "$BASE/iran-ipv4.txt" -o "$OUT/iran-ipv4.txt" || {
	echo "ERROR: Failed to download iran-ipv4.txt" >&2
	exit 1
}

echo "Fetching Iranian IPv6 prefixes..."
curl -sSL --max-time 120 "$BASE/iran-ipv6.txt" -o "$OUT/iran-ipv6.txt" || {
	echo "ERROR: Failed to download iran-ipv6.txt" >&2
	exit 1
}

echo "Fetching domestic domains..."
curl -sSL --max-time 60 "$BASE/domestic-domains.txt" -o "$OUT/domestic-domains.txt" 2>/dev/null || {
	echo "WARNING: domestic-domains.txt not available, using built-in list" >&2
}

python3 - "$OUT/iran-ipv4.txt" "$OUT/iran-ipv6.txt" <<'EOF'
import ipaddress, sys
total = 0
for path in sys.argv[1:]:
    try:
        for line in open(path):
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            ipaddress.ip_network(line)  # raises on junk
            total += 1
        print(f"OK: {path} - {total} prefixes")
    except FileNotFoundError:
        print(f"SKIP: {path} not found")
    except ValueError as e:
        print(f"ERROR: Invalid prefix in {path}: {e}", file=sys.stderr)
        sys.exit(1)
print(f"Total validated: {total} prefixes")
EOF

echo "Done. Files updated in $OUT"