#!/bin/sh
# ==============================================================================
# Shill PM Installer: rsync
# Downloads static rsync binary from ryanwoodsmall/static-binaries
# ==============================================================================

set -e

_log()  { printf '[shill:rsync] %s\n' "$*"; }
_die()  { printf '[shill:rsync] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:rsync] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    case "$(uname -m)" in
        x86_64|amd64)   _arch="x86_64" ;;
        aarch64|arm64)  _arch="aarch64" ;;
        *)              _die "Unsupported architecture: $(uname -m)" ;;
    esac

    _url="https://raw.githubusercontent.com/ryanwoodsmall/static-binaries/master/${_arch}/rsync"
    _target="$SHILL_CORE/bin/rsync"

    _log "Installing rsync (${_arch})..."
    curl -fsSL "$_url" -o "$_target" || _die "Download failed."
    chmod +x "$_target"

    _ok "rsync installed."
    "$SHILL_CORE/bin/rsync" --version 2>/dev/null | head -1 || true
}

_remove() {
    _log "Removing rsync..."
    rm -f "$SHILL_CORE/bin/rsync"
    _ok "rsync removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
