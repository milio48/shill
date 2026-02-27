#!/bin/sh
# ==============================================================================
# Shill PM Installer: deepce
# Downloads Deepce for Docker enumeration and exploitation
# ==============================================================================

set -e

_log()  { printf '[shill:deepce] %s\n' "$*"; }
_die()  { printf '[shill:deepce] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:deepce] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _url="https://github.com/stealthcopter/deepce/raw/main/deepce.sh"
    _target="$SHILL_CORE/bin/deepce"

    _log "Installing deepce..."

    # Download
    curl -fsSL "$_url" -o "$_target" || _die "Download failed."

    chmod +x "$_target"

    _ok "deepce installed successfully at $SHILL_CORE/bin/deepce"
}

_remove() {
    _log "Removing deepce..."
    rm -f "$SHILL_CORE/bin/deepce"
    _ok "deepce removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
