#!/bin/sh
# ==============================================================================
# Shill PM Installer: zellij
# Terminal workspace with batteries included
# ==============================================================================

set -e

ZELLIJ_VERSION="v0.44.3"

_log()  { printf '[shill:zellij] %s\n' "$*"; }
_die()  { printf '[shill:zellij] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:zellij] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _arch_raw=$(uname -m)
    _os_raw=$(uname -s)

    _zj_os=""
    case "$_os_raw" in
        Linux)  _zj_os="unknown-linux-musl" ;;
        Darwin) _zj_os="apple-darwin" ;;
        *)      _die "Unsupported OS: $_os_raw" ;;
    esac

    _zj_arch=""
    case "$_arch_raw" in
        x86_64|amd64)           _zj_arch="x86_64" ;;
        aarch64|arm64)          _zj_arch="aarch64" ;;
        *)                      _die "Unsupported architecture: $_arch_raw" ;;
    esac

    _target_bin="$SHILL_CORE/bin/zellij"
    _cache_dir="$SHILL_CORE/cache/zellij_dl"
    
    _filename="zellij-${_zj_arch}-${_zj_os}.tar.gz"
    _url="https://github.com/zellij-org/zellij/releases/download/${ZELLIJ_VERSION}/${_filename}"

    _log "Installing Zellij ${ZELLIJ_VERSION} (${_zj_arch} ${_zj_os})..."

    # 1. Download
    mkdir -p "$_cache_dir"
    _archive_file="$_cache_dir/$_filename"

    _log "Downloading Zellij..."
    curl -fsSL "$_url" -o "$_archive_file" || _die "Download failed. Check your connection or the release link: $_url"

    # 2. Extract
    _log "Extracting Zellij..."
    tar -xzf "$_archive_file" -C "$_cache_dir" || _die "Extraction failed. Be sure 'tar' is available."

    # 3. Install binary
    _log "Installing binary..."
    _extracted_bin="$_cache_dir/zellij"

    if [ ! -f "$_extracted_bin" ]; then
        _die "zellij binary not found in extracted files."
    fi

    cp -f "$_extracted_bin" "$_target_bin"
    chmod +x "$_target_bin"

    # Cleanup
    rm -rf "$_cache_dir"

    _ok "zellij installed successfully at $_target_bin"
}

_remove() {
    _log "Removing zellij..."
    rm -f "$SHILL_CORE/bin/zellij"
    _ok "zellij removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
