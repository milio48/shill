#!/bin/sh
# ==============================================================================
# Shill PM Installer: FrankenPHP
# Downloads FrankenPHP standalone binary from GitHub Releases
# ==============================================================================

set -e

FRANKENPHP_VERSION="1.4.4"

_log()  { printf '[shill:frankenphp] %s\n' "$*"; }
_die()  { printf '[shill:frankenphp] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:frankenphp] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)   _arch="x86_64" ;;
        aarch64|arm64)  _arch="aarch64" ;;
        *)              _die "Unsupported architecture: $(uname -m)" ;;
    esac

    _binary="frankenphp-linux-${_arch}"
    _url="https://github.com/dunglas/frankenphp/releases/download/v${FRANKENPHP_VERSION}/${_binary}"
    _target="$SHILL_CORE/bin/frankenphp"

    _log "Installing FrankenPHP v${FRANKENPHP_VERSION} (${_arch})..."

    # Download
    _log "Downloading from GitHub Releases..."
    curl -fsSL "$_url" -o "$_target" || _die "Download failed. Check version or architecture."

    chmod +x "$_target"

    _ok "FrankenPHP v${FRANKENPHP_VERSION} installed."
    "$SHILL_CORE/bin/frankenphp" version 2>/dev/null || true
}

_remove() {
    _log "Removing FrankenPHP..."
    rm -f "$SHILL_CORE/bin/frankenphp"
    _ok "FrankenPHP removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
