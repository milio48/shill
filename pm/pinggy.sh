#!/bin/sh
# ==============================================================================
# Shill PM Installer: pinggy
# Creates a wrapper script for Pinggy.io tunnel
# ==============================================================================

set -e

_log()  { printf '[shill:pinggy] %s\n' "$*"; }
_die()  { printf '[shill:pinggy] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:pinggy] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _log "Creating pinggy wrapper script..."
    _target="$SHILL_CORE/bin/pinggy"

    cat <<'EOF' > "$_target"
#!/bin/sh
# Pinggy.io tunnel wrapper for Shill
# Usage: pinggy [port]

PORT=${1:-8080}

if command -v ssh >/dev/null 2>&1; then
    echo "🚀 tunnel Pinggy on port: $PORT"
    exec ssh -t -p 443 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -R 0:127.0.0.1:$PORT qr@free.pinggy.io
elif command -v dbclient >/dev/null 2>&1; then
    echo "🚀 tunnel Pinggy (via Dropbear) on port: $PORT"
    # Dropbear dbclient -R format
    exec dbclient -y -p 443 -R 0:127.0.0.1:$PORT qr@free.pinggy.io
else
        echo "❌ Error: ssh (OpenSSH) or dbclient (Dropbear) not found."
        echo "💡 Tip: Run './shill.sh install dropbearmulti' first."
    exit 1
fi
EOF

    chmod +x "$_target"
    _ok "pinggy wrapper created at $SHILL_CORE/bin/pinggy"
}

_remove() {
    _log "Removing pinggy..."
    rm -f "$SHILL_CORE/bin/pinggy"
    _ok "pinggy removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
