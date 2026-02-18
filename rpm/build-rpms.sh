#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
VERSION="${1:-1.0.0}"
TOPDIR="$SCRIPT_DIR/rpmbuild"

echo "=== Building OpenClaw Cursor RPMs ==="
echo "Version: $VERSION"
echo ""

# Setup rpmbuild tree
mkdir -p "$TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Build the Go binary
echo "[1/4] Building proxy binary..."
cd "$REPO_DIR/openclaw"
make build 2>&1
cp bin/openclaw-cursor "$TOPDIR/SOURCES/"

# Copy spec files
echo "[2/4] Copying spec files..."
cp "$SCRIPT_DIR"/openclaw-cursor-proxy.spec "$TOPDIR/SPECS/"
cp "$SCRIPT_DIR"/openclaw-cursor-client.spec "$TOPDIR/SPECS/"
cp "$SCRIPT_DIR"/qubes-openclaw-policy.spec "$TOPDIR/SPECS/"

# Copy sources
echo "[3/4] Copying source files..."
cp "$SCRIPT_DIR"/sources/* "$TOPDIR/SOURCES/"

# System-level qubes-managed units (RPM versions with standard paths)
# These are already in $SCRIPT_DIR/sources/ with correct /usr/bin paths
# Only copy from qubes-integration if RPM-specific ones are missing
for unit in qubes-openclaw-proxy qubes-openclaw-gateway qubes-openclaw-watchdog qubes-openclaw-tunnels; do
    if [ ! -f "$TOPDIR/SOURCES/${unit}.service" ]; then
        cp "$REPO_DIR/qubes-integration/systemd/${unit}.service" "$TOPDIR/SOURCES/" 2>/dev/null || true
    fi
done

# Scripts
cp "$REPO_DIR"/qubes-integration/scripts/setup-vm.sh "$TOPDIR/SOURCES/"
cp "$REPO_DIR"/qubes-integration/scripts/monitor-dashboard.sh "$TOPDIR/SOURCES/"
cp "$REPO_DIR"/qubes-integration/scripts/openclaw-watchdog.sh "$TOPDIR/SOURCES/"
cp "$REPO_DIR"/qubes-integration/scripts/openclaw-wait-ready.sh "$TOPDIR/SOURCES/"
cp "$REPO_DIR"/qubes-integration/scripts/openclaw-ctl "$TOPDIR/SOURCES/"
cp "$REPO_DIR"/qubes-integration/scripts/openclaw-ctl "$TOPDIR/SOURCES/openclaw-ctl-client"
cp "$REPO_DIR"/qubes-integration/scripts/client-connect.sh "$TOPDIR/SOURCES/openclaw-connect.sh"
cp "$REPO_DIR"/qubes-integration/scripts/openclaw-tunnel-daemon.sh "$TOPDIR/SOURCES/"
cp "$REPO_DIR"/qubes-integration/scripts/test-connecttcp.sh "$TOPDIR/SOURCES/"

# Build RPMs
echo "[4/4] Building RPMs..."
for spec in openclaw-cursor-proxy openclaw-cursor-client qubes-openclaw-policy; do
    echo "  Building $spec..."
    rpmbuild --define "_topdir $TOPDIR" \
             --define "_sourcedir $TOPDIR/SOURCES" \
             --define "version $VERSION" \
             -bb "$TOPDIR/SPECS/$spec.spec" 2>&1 | tail -3
done

echo ""
echo "=== RPMs built ==="
find "$TOPDIR/RPMS" -name "*.rpm" -exec echo "  {}" \;
