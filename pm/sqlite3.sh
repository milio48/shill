#!/bin/sh
# ==============================================================================
# Shill PM Installer: sqlite3
# Static SQLite3 command-line interface
# ==============================================================================

set -e

_log()  { printf '[shill:sqlite3] %s\n' "$*"; }
_die()  { printf '[shill:sqlite3] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:sqlite3] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _os_raw=$(uname -s)
    _arch_raw=$(uname -m)

    [ "$_os_raw" != "Linux" ] && _die "Only Linux is supported."

    _arch=""
    case "$_arch_raw" in
        x86_64|amd64)           _arch="x86_64" ;;
        aarch64|arm64)          _arch="aarch64" ;;
        armv7l|armv6l|armhf)    _arch="armhf" ;;
        *)                      _die "Unsupported architecture: $_arch_raw" ;;
    esac

    _target_bin="$SHILL_CORE/bin/sqlite3"
    _url="https://raw.githubusercontent.com/ryanwoodsmall/static-binaries/master/${_arch}/sqlite3"

    _log "Installing sqlite3 static binary (${_arch})..."

    _log "Downloading sqlite3..."
    curl -fsSL "$_url" -o "$_target_bin" || _die "Download failed."

    chmod +x "$_target_bin"

    _ok "sqlite3 installed successfully at $_target_bin"
}

_remove() {
    _log "Removing sqlite3..."
    rm -f "$SHILL_CORE/bin/sqlite3"
    _ok "sqlite3 removed."
}

case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
