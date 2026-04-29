#!/bin/sh
# ==============================================================================
# Shill PM Installer: chisel
# A fast TCP/UDP tunnel over HTTP
# ==============================================================================

set -e

_log()  { printf '[shill:chisel] %s\n' "$*"; }
_die()  { printf '[shill:chisel] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:chisel] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _os_raw=$(uname -s)
    _arch_raw=$(uname -m)

    # 1. Map OS & Architecture
    _os=""
    case "$_os_raw" in
        Linux)  _os="linux" ;;
        Darwin) _os="darwin" ;;
        *)      _die "Unsupported OS: $_os_raw" ;;
    esac

    _arch=""
    case "$_arch_raw" in
        x86_64|amd64)           _arch="amd64" ;;
        aarch64|arm64)          _arch="arm64" ;;
        armv7l)                 _arch="armv7" ;;
        armv6l)                 _arch="armv6" ;;
        armv5l)                 _arch="armv5" ;;
        i386|i686)              _arch="386" ;;
        *)                      _die "Unsupported architecture: $_arch_raw" ;;
    esac

    # 2. Fetch latest release version from GitHub API
    _log "Fetching latest version info..."
    _curl_cmd="curl"
    [ -x "$SHILL_CORE/bin/curl" ] && _curl_cmd="$SHILL_CORE/bin/curl"
    
    _api_url="https://api.github.com/repos/jpillora/chisel/releases/latest"
    CHISEL_VERSION=$("$_curl_cmd" -fsSL "$_api_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$CHISEL_VERSION" ]; then
        _die "Failed to fetch latest version from GitHub."
    fi

    # Remove 'v' from version for asset name formatting
    _ver_no_v=$(echo "$CHISEL_VERSION" | sed 's/^v//')

    _target_bin="$SHILL_CORE/bin/chisel"
    _cache_dir="$SHILL_CORE/cache/chisel_dl"
    
    # Asset name format: chisel_1.11.5_linux_amd64.gz
    _filename="chisel_${_ver_no_v}_${_os}_${_arch}.gz"
    _url="https://github.com/jpillora/chisel/releases/download/${CHISEL_VERSION}/${_filename}"

    _log "Installing chisel ${CHISEL_VERSION} (${_os} ${_arch})..."

    # 3. Download
    mkdir -p "$_cache_dir"
    _archive_file="$_cache_dir/$_filename"

    _log "Downloading chisel..."
    "$_curl_cmd" -fsSL "$_url" -o "$_archive_file" || _die "Download failed. URL: $_url"

    # 4. Extract
    _log "Extracting..."
    # The file is a gzipped binary, not a tarball
    gzip -d "$_archive_file" || _die "Extraction failed. Is 'gzip' available?"

    # 5. Install Binary
    _log "Installing binary..."
    _extracted_bin="${_archive_file%.gz}"
    
    if [ ! -f "$_extracted_bin" ]; then
        _die "Binary not found after extraction."
    fi

    cp -f "$_extracted_bin" "$_target_bin"
    chmod +x "$_target_bin"

    # 6. Cleanup
    rm -rf "$_cache_dir"

    _ok "chisel installed successfully at $_target_bin"
}

_remove() {
    _log "Removing chisel..."
    rm -f "$SHILL_CORE/bin/chisel"
    _ok "chisel removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
