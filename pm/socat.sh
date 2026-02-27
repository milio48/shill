#!/bin/sh
# ==============================================================================
# Shill PM Installer: socat
# Downloads static socat binary from ryanwoodsmall/static-binaries
# ==============================================================================

set -e

_log()  { printf '[shill:socat] %s\n' "$*"; }
_die()  { printf '[shill:socat] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:socat] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    case "$(uname -m)" in
        x86_64|amd64)   _arch="x86_64" ;;
        aarch64|arm64)  _arch="aarch64" ;;
        *)              _die "Unsupported architecture: $(uname -m)" ;;
    esac

    _url="https://raw.githubusercontent.com/ryanwoodsmall/static-binaries/master/${_arch}/socat"
    _target="$SHILL_CORE/bin/socat"

    _log "Installing socat (${_arch})..."
    curl -fsSL "$_url" -o "$_target" || _die "Download failed."
    chmod +x "$_target"

    _ok "socat installed."
    "$SHILL_CORE/bin/socat" -V 2>/dev/null | head -1 || true
}

_remove() {
    _log "Removing socat..."
    rm -f "$SHILL_CORE/bin/socat"
    _ok "socat removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
