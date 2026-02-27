#!/bin/sh
# ==============================================================================
# Shill PM Installer: GNU Screen
# Downloads static screen binary from ryanwoodsmall/static-binaries
# ==============================================================================

set -e

_log()  { printf '[shill:screen] %s\n' "$*"; }
_die()  { printf '[shill:screen] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:screen] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    case "$(uname -m)" in
        x86_64|amd64)   _arch="x86_64" ;;
        aarch64|arm64)  _arch="aarch64" ;;
        *)              _die "Unsupported architecture: $(uname -m)" ;;
    esac

    _url="https://raw.githubusercontent.com/ryanwoodsmall/static-binaries/master/${_arch}/screen"
    _target="$SHILL_CORE/bin/screen"

    _log "Installing screen (${_arch})..."
    curl -fsSL "$_url" -o "$_target" || _die "Download failed."
    chmod +x "$_target"

    _ok "GNU Screen installed."
    "$SHILL_CORE/bin/screen" --version 2>/dev/null || true
}

_remove() {
    _log "Removing screen..."
    rm -f "$SHILL_CORE/bin/screen"
    _ok "screen removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
