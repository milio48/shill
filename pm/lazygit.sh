#!/bin/sh
# ==============================================================================
# Shill PM Installer: lazygit
# Simple terminal UI for git commands
# ==============================================================================

set -e

LAZYGIT_VERSION="v0.59.0"

_log()  { printf '[shill:lazygit] %s\n' "$*"; }
_die()  { printf '[shill:lazygit] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:lazygit] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _arch_raw=$(uname -m)
    _os_raw=$(uname -s)

    _lg_os=""
    case "$_os_raw" in
        Linux)  _lg_os="linux" ;;
        Darwin) _lg_os="darwin" ;;
        *)      _die "Unsupported OS: $_os_raw" ;;
    esac

    _lg_arch=""
    case "$_arch_raw" in
        x86_64|amd64)           _lg_arch="x86_64" ;;
        aarch64|arm64)          _lg_arch="arm64" ;;
        armv6l|armv7l|armhf)    _lg_arch="armv6" ;;
        i386|i686)              _lg_arch="32-bit" ;;
        *)                      _die "Unsupported architecture: $_arch_raw" ;;
    esac

    # Remove 'v' from version for the filename part
    _ver_no_v=$(echo "$LAZYGIT_VERSION" | sed 's/^v//')

    _target_bin="$SHILL_CORE/bin/lazygit"
    _cache_dir="$SHILL_CORE/cache/lazygit_dl"
    
    _filename="lazygit_${_ver_no_v}_${_lg_os}_${_lg_arch}.tar.gz"
    _url="https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}/${_filename}"

    _log "Installing Lazygit ${LAZYGIT_VERSION} (${_lg_os} ${_lg_arch})..."

    # 1. Download
    mkdir -p "$_cache_dir"
    _archive_file="$_cache_dir/$_filename"

    _log "Downloading Lazygit..."
    curl -fsSL "$_url" -o "$_archive_file" || _die "Download failed. Check your connection or the release link: $_url"

    # 2. Extract
    _log "Extracting Lazygit..."
    tar -xzf "$_archive_file" -C "$_cache_dir" || _die "Extraction failed. Be sure 'tar' is available."

    # 3. Install binary
    _log "Installing binary..."
    _extracted_bin="$_cache_dir/lazygit"

    if [ ! -f "$_extracted_bin" ]; then
        _die "lazygit binary not found in extracted files."
    fi

    cp -f "$_extracted_bin" "$_target_bin"
    chmod +x "$_target_bin"

    # Cleanup
    rm -rf "$_cache_dir"

    _ok "lazygit installed successfully at $_target_bin"
}

_remove() {
    _log "Removing lazygit..."
    rm -f "$SHILL_CORE/bin/lazygit"
    _ok "lazygit removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
