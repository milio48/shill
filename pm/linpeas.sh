#!/bin/sh
# ==============================================================================
# Shill PM Installer: linpeas
# Downloads the latest linpeas.sh for local privilege escalation enumeration
# ==============================================================================

set -e

_log()  { printf '[shill:linpeas] %s\n' "$*"; }
_die()  { printf '[shill:linpeas] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:linpeas] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _url="https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh"
    _target="$SHILL_CORE/bin/linpeas"

    _log "Installing linpeas..."

    # Download
    curl -fsSL "$_url" -o "$_target" || _die "Download failed."

    chmod +x "$_target"

    _ok "linpeas installed successfully at $SHILL_CORE/bin/linpeas"
}

_remove() {
    _log "Removing linpeas..."
    rm -f "$SHILL_CORE/bin/linpeas"
    _ok "linpeas removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
