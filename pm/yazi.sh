#!/bin/sh
# ==============================================================================
# Shill PM Installer: yazi
# Blazing fast terminal file manager written in Rust, based on async I/O.
# ==============================================================================

set -e

YAZI_VERSION="v26.1.22"

_log()  { printf '[shill:yazi] %s\n' "$*"; }
_die()  { printf '[shill:yazi] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:yazi] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _arch_raw=$(uname -m)
    _os_raw=$(uname -s)

    _yazi_target=""
    case "$_os_raw" in
        Linux)
            case "$_arch_raw" in
                x86_64|amd64)   _yazi_target="x86_64-unknown-linux-musl" ;;
                aarch64|arm64)  _yazi_target="aarch64-unknown-linux-musl" ;;
                *)              _die "Unsupported architecture on Linux: $_arch_raw" ;;
            esac
            ;;
        Darwin)
            case "$_arch_raw" in
                x86_64|amd64)   _yazi_target="x86_64-apple-darwin" ;;
                aarch64|arm64)  _yazi_target="aarch64-apple-darwin" ;;
                *)              _die "Unsupported architecture on Darwin: $_arch_raw" ;;
            esac
            ;;
        *)
            _die "Unsupported OS: $_os_raw"
            ;;
    esac

    _target_bin="$SHILL_CORE/bin/yazi"
    _target_ya="$SHILL_CORE/bin/ya"
    
    _cache_dir="$SHILL_CORE/cache/yazi_dl"
    _zip_file="$_cache_dir/yazi.zip"
    
    _url="https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-${_yazi_target}.zip"

    _log "Installing Yazi ${YAZI_VERSION} (${_yazi_target})..."

    # 1. Download
    mkdir -p "$_cache_dir"
    _log "Downloading Yazi..."
    curl -fsSL "$_url" -o "$_zip_file" || _die "Download failed. Check your connection or the release link."

    # 2. Extract
    _log "Extracting Yazi..."
    unzip -q -o "$_zip_file" -d "$_cache_dir" || _die "Extraction failed. Be sure 'unzip' is available."

    # 3. Install binaries
    _log "Installing binaries..."
    # The zip creates a directory named "yazi-${_yazi_target}"
    _extracted_dir="$_cache_dir/yazi-${_yazi_target}"

    if [ ! -d "$_extracted_dir" ]; then
        # Fallback to search if directory structure changed
        _yazi_bin=$(find "$_cache_dir" -type f -name "yazi" | head -n 1)
        _ya_bin=$(find "$_cache_dir" -type f -name "ya" | head -n 1)
    else
        _yazi_bin="$_extracted_dir/yazi"
        _ya_bin="$_extracted_dir/ya"
    fi

    if [ ! -f "$_yazi_bin" ]; then
        _die "yazi binary not found in extracted files."
    fi

    cp -f "$_yazi_bin" "$_target_bin"
    [ -f "$_ya_bin" ] && cp -f "$_ya_bin" "$_target_ya"
    
    chmod +x "$_target_bin"
    [ -f "$_ya_bin" ] && chmod +x "$_target_ya"

    # Cleanup
    rm -rf "$_cache_dir"

    _ok "yazi installed successfully at $_target_bin"
}

_remove() {
    _log "Removing yazi..."
    rm -f "$SHILL_CORE/bin/yazi"
    rm -f "$SHILL_CORE/bin/ya"
    _ok "yazi removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
