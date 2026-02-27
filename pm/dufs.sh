#!/bin/sh
# ==============================================================================
# Shill PM Installer: dufs
# Downloads and installs dufs - a distinctive file server
# ==============================================================================

set -e

DUFS_VERSION="v0.45.0"

_log()  { printf '[shill:dufs] %s\n' "$*"; }
_die()  { printf '[shill:dufs] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:dufs] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    # Detect architecture
    _arch_raw=$(uname -m)
    case "$_arch_raw" in
        x86_64|amd64)   _target="x86_64-unknown-linux-musl" ;;
        aarch64|arm64)  _target="aarch64-unknown-linux-musl" ;;
        *)              _die "Unsupported architecture: $_arch_raw" ;;
    esac

    _file="dufs-${DUFS_VERSION}-${_target}.tar.gz"
    _url="https://github.com/sigoden/dufs/releases/download/${DUFS_VERSION}/${_file}"
    _cache="$SHILL_CORE/cache"
    _tgz="$_cache/$_file"
    _bin_dir="$SHILL_CORE/bin"

    _log "Installing dufs ${DUFS_VERSION} (${_target})..."

    # Download
    _log "Downloading from GitHub Releases..."
    curl -fsSL "$_url" -o "$_tgz" || _die "Download failed."

    # Extract
    _log "Extracting..."
    tar -xzf "$_tgz" -C "$_bin_dir" dufs || _die "Extraction failed."
    chmod +x "$_bin_dir/dufs"

    # Cleanup
    rm -f "$_tgz"

    _ok "dufs installed successfully at $SHILL_CORE/bin/dufs"
    "$_bin_dir/dufs" --version 2>/dev/null || true
}

_remove() {
    _log "Removing dufs..."
    rm -f "$SHILL_CORE/bin/dufs"
    _ok "dufs removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
