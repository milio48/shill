#!/bin/sh
# ==============================================================================
# Shill PM Installer: sshx
# Downloads the latest sshx binary from sshx.io
# ==============================================================================

set -e

_log()  { printf '[shill:sshx] %s\n' "$*"; }
_die()  { printf '[shill:sshx] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:sshx] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    case "$(uname -m)" in
        aarch64|aarch64_be|arm64|armv8b|armv8l) _arch="aarch64" ;;
        x86_64|x64|amd64)                       _arch="x86_64" ;;
        armv6l)                                  _arch="arm"; _extra="eabihf" ;;
        armv7l)                                  _arch="armv7"; _extra="eabihf" ;;
        *)  _die "Unsupported architecture: $(uname -m)" ;;
    esac

    case "$(uname -s)" in
        Linux*)   _suffix="-unknown-linux-musl${_extra}" ;;
        Darwin*)  _suffix="-apple-darwin" ;;
        FreeBSD*) _suffix="-unknown-freebsd" ;;
        *)        _die "Unsupported OS: $(uname -s)" ;;
    esac

    _url="https://s3.amazonaws.com/sshx/sshx-${_arch}${_suffix}.tar.gz"
    _target="$SHILL_CORE/bin/sshx"
    _tmp=$(mktemp)

    _log "Installing sshx (${_arch}${_suffix})..."
    curl -fsSL "$_url" -o "$_tmp" || _die "Download failed."
    tar xzf "$_tmp" -C "$SHILL_CORE/bin" sshx || _die "Extract failed."
    rm -f "$_tmp"
    chmod +x "$_target"

    _ok "sshx installed."
    "$_target" --version 2>/dev/null || true
}

_remove() {
    _log "Removing sshx..."
    rm -f "$SHILL_CORE/bin/sshx"
    _ok "sshx removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
