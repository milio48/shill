#!/bin/sh
# ==============================================================================
# Shill PM Installer: btop
# A monitor of resources
# ==============================================================================

set -e

_log()  { printf '[shill:btop] %s\n' "$*"; }
_die()  { printf '[shill:btop] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:btop] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _os_raw=$(uname -s)
    if [ "$_os_raw" != "Linux" ]; then
        _die "btop musl binaries are currently only mapped for Linux."
    fi

    _arch_raw=$(uname -m)

    # 1. Map Architecture
    _arch=""
    case "$_arch_raw" in
        x86_64|amd64)           _arch="x86_64" ;;
        aarch64|arm64)          _arch="aarch64" ;;
        armv7l)                 _arch="armv7" ;;
        armv6l|armv5l)          _arch="arm" ;;
        i386|i686)              _arch="i686" ;;
        *)                      _die "Unsupported architecture: $_arch_raw" ;;
    esac

    # 2. Fetch latest release version from GitHub API
    _log "Fetching latest version info..."
    _curl_cmd="curl"
    [ -x "$SHILL_CORE/bin/curl" ] && _curl_cmd="$SHILL_CORE/bin/curl"
    
    _api_url="https://api.github.com/repos/aristocratos/btop/releases/latest"
    BTOP_VERSION=$("$_curl_cmd" -fsSL "$_api_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$BTOP_VERSION" ]; then
        _die "Failed to fetch latest version from GitHub."
    fi

    _target_bin="$SHILL_CORE/bin/btop"
    _cache_dir="$SHILL_CORE/cache/btop_dl"
    
    # Asset name format: btop-x86_64-unknown-linux-musl.tbz
    _filename="btop-${_arch}-unknown-linux-musl.tbz"
    _url="https://github.com/aristocratos/btop/releases/download/${BTOP_VERSION}/${_filename}"

    _log "Installing btop ${BTOP_VERSION} (${_arch})..."

    # 3. Download
    mkdir -p "$_cache_dir"
    _archive_file="$_cache_dir/$_filename"

    _log "Downloading btop..."
    "$_curl_cmd" -fsSL "$_url" -o "$_archive_file" || _die "Download failed. URL: $_url"

    # 4. Extract
    _log "Extracting..."
    # Using tar with j for bzip2 compression
    tar -xjf "$_archive_file" -C "$_cache_dir" || _die "Extraction failed. Is 'bzip2' installed?"

    # 5. Install Binary
    _log "Installing binary..."
    _extracted_bin=$(find "$_cache_dir" -type f -name "btop" | grep "bin/btop" | head -n 1)

    if [ -z "$_extracted_bin" ] || [ ! -f "$_extracted_bin" ]; then
        _extracted_bin=$(find "$_cache_dir" -type f -name "btop" | head -n 1)
    fi
    
    if [ -z "$_extracted_bin" ] || [ ! -f "$_extracted_bin" ]; then
        _die "Binary 'btop' not found after extraction."
    fi

    # Install as btop.bin
    cp -f "$_extracted_bin" "${_target_bin}.bin"
    chmod +x "${_target_bin}.bin"

    # Create wrapper to automatically bypass UTF-8 check
    cat <<EOF > "$_target_bin"
#!/bin/sh
exec "$SHILL_CORE/bin/btop.bin" --force-utf "\$@"
EOF
    chmod +x "$_target_bin"

    # 6. Cleanup
    rm -rf "$_cache_dir"

    _ok "btop installed successfully at $_target_bin"
}

_remove() {
    _log "Removing btop..."
    rm -f "$SHILL_CORE/bin/btop"
    rm -f "$SHILL_CORE/bin/btop.bin"
    _ok "btop removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
