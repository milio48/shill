#!/bin/sh
# ==============================================================================
# Shill PM Installer: bench
# Downloads the classic Bench.sh script by TeddySun for system benchmarks
# ==============================================================================

set -e

_log()  { printf '[shill:bench] %s\n' "$*"; }
_die()  { printf '[shill:bench] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:bench] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _url="https://raw.githubusercontent.com/teddysun/across/master/bench.sh"
    _target="$SHILL_CORE/bin/bench"

    _log "Installing bench.sh..."

    # Download using shill's curl wrapper
    curl -fsSL "$_url" -o "$_target" || _die "Download failed."

    chmod +x "$_target"

    _ok "bench installed successfully at $SHILL_CORE/bin/bench"
}

_remove() {
    _log "Removing bench..."
    rm -f "$SHILL_CORE/bin/bench"
    _ok "bench removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
