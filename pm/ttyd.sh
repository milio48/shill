#!/bin/sh
# ==============================================================================
# Shill PM Installer: ttyd
# Share your terminal over the web
# ==============================================================================

set -e

_log()  { printf '[shill:ttyd] %s\n' "$*"; }
_die()  { printf '[shill:ttyd] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:ttyd] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _os_raw=$(uname -s)
    if [ "$_os_raw" != "Linux" ]; then
        _die "ttyd official pre-compiled binaries are only available for Linux."
    fi

    _arch_raw=$(uname -m)

    # 1. Map Architecture
    _arch=""
    case "$_arch_raw" in
        x86_64|amd64)           _arch="x86_64" ;;
        aarch64|arm64)          _arch="aarch64" ;;
        armv7l)                 _arch="armhf" ;;
        armv6l|armv5l)          _arch="arm" ;;
        i386|i686)              _arch="i686" ;;
        *)                      _die "Unsupported architecture: $_arch_raw" ;;
    esac

    # 2. Fetch latest release version from GitHub API
    _log "Fetching latest version info..."
    _curl_cmd="curl"
    [ -x "$SHILL_CORE/bin/curl" ] && _curl_cmd="$SHILL_CORE/bin/curl"
    
    _api_url="https://api.github.com/repos/tsl0922/ttyd/releases/latest"
    TTYD_VERSION=$("$_curl_cmd" -fsSL "$_api_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$TTYD_VERSION" ]; then
        _die "Failed to fetch latest version from GitHub."
    fi

    _target_bin="$SHILL_CORE/bin/ttyd"
    _cache_bin="$SHILL_CORE/cache/ttyd_dl_bin"
    
    # Asset name format: ttyd.x86_64
    _filename="ttyd.${_arch}"
    _url="https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/${_filename}"

    _log "Installing ttyd ${TTYD_VERSION} (${_arch})..."

    # 3. Download directly to cache
    _log "Downloading ttyd..."
    "$_curl_cmd" -fsSL "$_url" -o "$_cache_bin" || _die "Download failed. URL: $_url"

    # 4. Install Binary (no extraction needed)
    _log "Installing binary..."
    cp -f "$_cache_bin" "$_target_bin"
    chmod +x "$_target_bin"

    # 5. Cleanup
    rm -f "$_cache_bin"

    _ok "ttyd installed successfully at $_target_bin"
}

_remove() {
    _log "Removing ttyd..."
    rm -f "$SHILL_CORE/bin/ttyd"
    _ok "ttyd removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
