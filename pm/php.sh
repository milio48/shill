#!/bin/sh
# ==============================================================================
# Shill PM Installer: Static PHP CLI
# Downloads a standalone PHP CLI binary from static-php.dev
# ==============================================================================

set -e

PHP_VERSION="8.3.0"

_log()  { printf '[shill:php] %s\n' "$*"; }
_die()  { printf '[shill:php] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:php] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)   _arch="x86_64" ;;
        aarch64|arm64)  _arch="aarch64" ;;
        *)              _die "Unsupported architecture: $(uname -m)" ;;
    esac

    _url="https://dl.static-php.dev/static-php-cli/common/php-${PHP_VERSION}-cli-linux-${_arch}.tar.gz"
    _tmp_tar="$SHILL_CORE/cache/php.tar.gz"
    _target="$SHILL_CORE/bin/php"

    _log "Installing Static PHP ${PHP_VERSION} (${_arch})..."

    # Download
    _log "Downloading from static-php.dev..."
    curl -fsSL "$_url" -o "$_tmp_tar" || _die "Download failed."

    # Extract
    _log "Extracting..."
    # The tarball contains a single file named 'php'
    tar -xzf "$_tmp_tar" -C "$SHILL_CORE/bin/" php || _die "Extraction failed."
    chmod +x "$_target"

    # Cleanup
    rm -f "$_tmp_tar"

    _ok "Static PHP installed successfully at $SHILL_CORE/bin/php"
    "$_target" -v | head -n 1
}

_remove() {
    _log "Removing Static PHP..."
    rm -f "$SHILL_CORE/bin/php"
    _ok "Static PHP removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
