#!/bin/sh
# Generate opkg repository index for local package hosting
# Usage: ./gen-repo.sh <directory-with-ipks>

set -eu

REPO_DIR="${1:-.}"
OUT_DIR="$REPO_DIR"

echo "Generating repository index in $REPO_DIR"

# Find all IPKs
IPKS=$(find "$REPO_DIR" -name "*.ipk" -type f | sort)

if [ -z "$IPKS" ]; then
	echo "No .ipk files found in $REPO_DIR"
	exit 1
fi

# Generate Packages.gz
echo "Generating Packages.gz..."
(
	for ipk in $IPKS; do
		# Extract control data
		ar -x "$ipk" control.tar.gz 2>/dev/null
		tar -xzf control.tar.gz ./control 2>/dev/null
		if [ -f ./control ]; then
			cat ./control
			echo "Filename: $(basename "$ipk")"
			echo "Size: $(stat -c%s "$ipk")"
			sha256=$(sha256sum "$ipk" | awk '{print $1}')
			echo "SHA256sum: $sha256"
			echo ""
			rm -f ./control control.tar.gz
		fi
	done
) | gzip -c > "$OUT_DIR/Packages.gz"

# Generate Packages (uncompressed)
(
	for ipk in $IPKS; do
		ar -x "$ipk" control.tar.gz 2>/dev/null
		tar -xzf control.tar.gz ./control 2>/dev/null
		if [ -f ./control ]; then
			cat ./control
			echo "Filename: $(basename "$ipk")"
			echo "Size: $(stat -c%s "$ipk")"
			sha256=$(sha256sum "$ipk" | awk '{print $1}')
			echo "SHA256sum: $sha256"
			echo ""
			rm -f ./control control.tar.gz
		fi
	done
) > "$OUT_DIR/Packages"

# Generate checksums
echo "Generating SHA256SUMS..."
cd "$REPO_DIR"
sha256sum *.ipk > SHA256SUMS.txt 2>/dev/null || true

echo "Repository index generated:"
ls -la "$OUT_DIR/Packages" "$OUT_DIR/Packages.gz" "$OUT_DIR/SHA256SUMS.txt" 2>/dev/null

echo ""
echo "To use this repository, add to /etc/opkg/customfeeds.conf:"
echo "src/gz luci-app-aether file://$REPO_DIR"
echo "Then run: opkg update"