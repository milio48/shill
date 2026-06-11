#!/bin/sh
# ==============================================================================
# Shill PM Installer: micro
# A modern and intuitive terminal-based text editor
# ==============================================================================

set -e

MICRO_VERSION="2.0.14"

_log()  { printf '[shill:micro] %s\n' "$*"; }
_die()  { printf '[shill:micro] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:micro] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _os_raw=$(uname -s)
    _arch_raw=$(uname -m)

    [ "$_os_raw" != "Linux" ] && _die "Only Linux is supported."

    _arch=""
    case "$_arch_raw" in
        x86_64|amd64)   _arch="64" ;;
        aarch64|arm64)  _arch="-arm64" ;;
        *)              _die "Unsupported architecture: $_arch_raw" ;;
    esac

    _target_bin="$SHILL_CORE/bin/micro"
    _cache_dir="$SHILL_CORE/cache/micro_dl"
    
    _filename="micro-${MICRO_VERSION}-linux${_arch}-static.tar.gz"
    _url="https://github.com/zyedidia/micro/releases/download/v${MICRO_VERSION}/${_filename}"

    _log "Installing micro v${MICRO_VERSION} (linux${_arch})..."

    mkdir -p "$_cache_dir"
    _archive_file="$_cache_dir/$_filename"

    _log "Downloading micro..."
    curl -fsSL "$_url" -o "$_archive_file" || _die "Download failed."

    _log "Extracting..."
    tar -xzf "$_archive_file" -C "$_cache_dir" || _die "Extraction failed."

    _log "Installing binary..."
    _extracted_bin="$_cache_dir/micro-${MICRO_VERSION}/micro"
    
    if [ ! -f "$_extracted_bin" ]; then
        _die "Binary not found in extracted files."
    fi

    cp -f "$_extracted_bin" "$_target_bin"
    chmod +x "$_target_bin"

    rm -rf "$_cache_dir"

    _ok "micro installed successfully at $_target_bin"
}

_remove() {
    _log "Removing micro..."
    rm -f "$SHILL_CORE/bin/micro"
    _ok "micro removed."
}

case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
