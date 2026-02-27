#!/bin/sh
# ==============================================================================
# Shill PM Installer: yabs
# Downloads Yet Another Bench Script (YABS) for comprehensive VPS benchmarking
# ==============================================================================

set -e

_log()  { printf '[shill:yabs] %s\n' "$*"; }
_die()  { printf '[shill:yabs] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:yabs] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _url="https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/yabs.sh"
    _target="$SHILL_CORE/bin/yabs"

    _log "Installing YABS..."

    # Download using shill's curl wrapper
    curl -fsSL "$_url" -o "$_target" || _die "Download failed."

    chmod +x "$_target"

    _ok "yabs installed successfully at $SHILL_CORE/bin/yabs"
}

_remove() {
    _log "Removing yabs..."
    rm -f "$SHILL_CORE/bin/yabs"
    _ok "yabs removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
