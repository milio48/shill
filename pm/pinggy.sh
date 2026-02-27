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
# Usage: 
#   pinggy <port>          (default http)
#   pinggy <proto> <port>  (e.g. pinggy tcp 8081)

_print_help() {
    echo "Usage: pinggy [protocol] <port>"
    echo ""
    echo "Protocols: http (default), tcp, tls"
    echo "Example: pinggy tcp 8081"
    exit 0
}

PROTO="http"
PORT=""

case "$1" in
    "") _print_help ;;
    help|--help|-h) _print_help ;;
    http|tcp|tls) PROTO="$1"; PORT="$2" ;;
    [0-9]*) PORT="$1" ;;
    *) echo "❌ Unknown argument: $1"; exit 1 ;;
esac

[ -z "$PORT" ] && PORT="8080"

if [ "$PROTO" = "http" ]; then
    SSH_USER="qr"
else
    SSH_USER="qr+$PROTO"
fi

if command -v ssh >/dev/null 2>&1; then
    echo "🚀 Tunneling $PROTO on port: $PORT"
    exec ssh -t -p 443 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -R 0:127.0.0.1:$PORT "$SSH_USER@free.pinggy.io"
elif command -v dbclient >/dev/null 2>&1; then
    echo "🚀 Tunneling $PROTO (via Dropbear) on port: $PORT"
    exec dbclient -y -p 443 -R 0:127.0.0.1:$PORT "$SSH_USER@free.pinggy.io"
else
    echo "❌ Error: ssh or dbclient not found."
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
