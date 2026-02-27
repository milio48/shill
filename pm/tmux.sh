#!/bin/sh
# ==============================================================================
# Shill PM Installer: tmux
# Downloads static tmux binary from ryanwoodsmall/static-binaries
# ==============================================================================

set -e

_log()  { printf '[shill:tmux] %s\n' "$*"; }
_die()  { printf '[shill:tmux] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:tmux] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    case "$(uname -m)" in
        x86_64|amd64)   _arch="x86_64" ;;
        aarch64|arm64)  _arch="aarch64" ;;
        *)              _die "Unsupported architecture: $(uname -m)" ;;
    esac

    _url="https://raw.githubusercontent.com/ryanwoodsmall/static-binaries/master/${_arch}/tmux"
    _target="$SHILL_CORE/bin/tmux"

    _log "Installing tmux (${_arch})..."
    curl -fsSL "$_url" -o "$_target" || _die "Download failed."
    chmod +x "$_target"

    _ok "tmux installed."
    "$SHILL_CORE/bin/tmux" -V 2>/dev/null || true
}

_remove() {
    _log "Removing tmux..."
    rm -f "$SHILL_CORE/bin/tmux"
    _ok "tmux removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
