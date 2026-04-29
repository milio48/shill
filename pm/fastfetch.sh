#!/bin/sh
# ==============================================================================
# Shill PM Installer: fastfetch
# Like neofetch, but much faster because written in C
# ==============================================================================

set -e

_log()  { printf '[shill:fastfetch] %s\n' "$*"; }
_die()  { printf '[shill:fastfetch] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:fastfetch] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _os_raw=$(uname -s)
    _arch_raw=$(uname -m)

    # 1. Map OS & Architecture
    _os=""
    case "$_os_raw" in
        Linux)  _os="linux" ;;
        Darwin) _os="macos" ;;
        *)      _die "Unsupported OS: $_os_raw" ;;
    esac

    _arch=""
    case "$_arch_raw" in
        x86_64|amd64)           _arch="amd64" ;;
        aarch64|arm64)          _arch="aarch64" ;;
        armv7l)                 _arch="armv7l" ;;
        armv6l)                 _arch="armv6l" ;;
        i386|i686)              _arch="i686" ;;
        *)                      _die "Unsupported architecture: $_arch_raw" ;;
    esac

    # 2. Fetch latest release version from GitHub API
    _log "Fetching latest version info..."
    # Use curl wrapper if available, else system curl
    _curl_cmd="curl"
    [ -x "$SHILL_CORE/bin/curl" ] && _curl_cmd="$SHILL_CORE/bin/curl"
    
    _api_url="https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest"
    FASTFETCH_VERSION=$("$_curl_cmd" -fsSL "$_api_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$FASTFETCH_VERSION" ]; then
        _die "Failed to fetch latest version from GitHub."
    fi

    _target_bin="$SHILL_CORE/bin/fastfetch"
    _cache_dir="$SHILL_CORE/cache/fastfetch_dl"
    
    _filename="fastfetch-${_os}-${_arch}.tar.gz"
    _url="https://github.com/fastfetch-cli/fastfetch/releases/download/${FASTFETCH_VERSION}/${_filename}"

    _log "Installing fastfetch ${FASTFETCH_VERSION} (${_os} ${_arch})..."

    # 3. Download
    mkdir -p "$_cache_dir"
    _archive_file="$_cache_dir/$_filename"

    _log "Downloading fastfetch..."
    "$_curl_cmd" -fsSL "$_url" -o "$_archive_file" || _die "Download failed. URL: $_url"

    # 4. Extract
    _log "Extracting..."
    tar -xzf "$_archive_file" -C "$_cache_dir" || _die "Extraction failed."

    # 5. Install Binary
    _log "Installing binary..."
    # The fastfetch binary is usually in usr/bin/fastfetch inside the extracted folder
    _extracted_bin=$(find "$_cache_dir" -type f -name "fastfetch" | grep "usr/bin/fastfetch" | head -n 1)
    
    # Fallback: if not found under usr/bin, just find any file named fastfetch
    if [ -z "$_extracted_bin" ] || [ ! -f "$_extracted_bin" ]; then
        _extracted_bin=$(find "$_cache_dir" -type f -name "fastfetch" | head -n 1)
    fi

    if [ -z "$_extracted_bin" ] || [ ! -f "$_extracted_bin" ]; then
        _die "Binary 'fastfetch' not found in extracted files."
    fi

    cp -f "$_extracted_bin" "$_target_bin"
    chmod +x "$_target_bin"

    # 6. Cleanup
    rm -rf "$_cache_dir"

    _ok "fastfetch installed successfully at $_target_bin"
}

_remove() {
    _log "Removing fastfetch..."
    rm -f "$SHILL_CORE/bin/fastfetch"
    _ok "fastfetch removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
