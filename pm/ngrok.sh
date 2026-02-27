#!/bin/sh
# ==============================================================================
# Shill PM Installer: ngrok
# Downloads and installs the latest stable ngrok v3 binary
# ==============================================================================

set -e

_log()  { printf '[shill:ngrok] %s\n' "$*"; }
_die()  { printf '[shill:ngrok] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:ngrok] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)   _arch="amd64" ;;
        aarch64|arm64)  _arch="arm64" ;;
        armv*)          _arch="arm" ;;
        i386|i686)      _arch="386" ;;
        *)              _die "Unsupported architecture: $(uname -m)" ;;
    esac

    _url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-${_arch}.tgz"
    _cache="$SHILL_CORE/cache"
    _tgz="$_cache/ngrok.tgz"
    _target="$SHILL_CORE/bin/ngrok"

    _log "Installing ngrok v3 (${_arch})..."

    # Download
    _log "Downloading from equinox.io..."
    curl -fsSL "$_url" -o "$_tgz" || _die "Download failed."

    # Extract
    _log "Extracting..."
    tar -xzf "$_tgz" -C "$SHILL_CORE/bin"
    chmod +x "$_target"

    # Cleanup
    rm -f "$_tgz"

    _ok "ngrok installed successfully."
    "$_target" --version 2>/dev/null || true
}

_remove() {
    _log "Removing ngrok..."
    rm -f "$SHILL_CORE/bin/ngrok"
    _ok "ngrok removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
