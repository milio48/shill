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

_append_env() {
    _env_file="$SHILL_CORE/etc/env.sh"
    mkdir -p "$SHILL_CORE/etc"
    [ -f "$_env_file" ] || printf '# Shill environment contract (managed automatically by pm/*.sh)\n' > "$_env_file"
    grep -q '>>> shill:php >>>' "$_env_file" && return 0
    cat <<EOF >> "$_env_file"

# >>> shill:php >>>
export PHPRC="$SHILL_CORE/etc/php"
# <<< shill:php <<<
EOF
}

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

    # Optimization for Development: Install Composer
    _log "Installing Composer (PHP Dependency Manager)..."
    if curl -fsSL "https://getcomposer.org/composer-stable.phar" -o "$SHILL_CORE/bin/composer"; then
        chmod +x "$SHILL_CORE/bin/composer"
        _ok "Composer installed."
    else
        _log "Note: Could not install Composer."
    fi

    # Optimization for Development: Create php.ini (read via PHPRC, the CLI
    # does NOT auto-load a php.ini sitting next to the binary on Linux)
    _log "Configuring PHP for development..."
    mkdir -p "$SHILL_CORE/etc/php"
    if [ ! -f "$SHILL_CORE/etc/php/php.ini" ]; then
        echo "memory_limit=-1" > "$SHILL_CORE/etc/php/php.ini"
        echo "display_errors=On" >> "$SHILL_CORE/etc/php/php.ini"
        echo "error_reporting=E_ALL" >> "$SHILL_CORE/etc/php/php.ini"
    fi
    _append_env

    _ok "Static PHP installed successfully at $SHILL_CORE/bin/php"
    "$_target" -v | head -n 1
}

_remove() {
    _log "Removing Static PHP..."
    rm -f "$SHILL_CORE/bin/php"
    rm -f "$SHILL_CORE/bin/composer"
    rm -f "$SHILL_CORE/bin/php.ini"
    rm -rf "$SHILL_CORE/etc/php"
    if [ -f "$SHILL_CORE/etc/env.sh" ]; then
        sed -i '/# >>> shill:php >>>/,/# <<< shill:php <<</d' "$SHILL_CORE/etc/env.sh" 2>/dev/null || true
    fi
    _ok "Static PHP removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
