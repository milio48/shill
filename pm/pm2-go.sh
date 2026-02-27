#!/bin/sh
# ==============================================================================
# Shill PM Installer: PM2-GO
# Downloads pm2-go binary from GitHub Releases
# ==============================================================================

set -e

PM2_GO_VERSION="0.1.2"

_log()  { printf '[shill:pm2-go] %s\n' "$*"; }
_die()  { printf '[shill:pm2-go] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:pm2-go] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)   _arch="amd64" ;;
        aarch64|arm64)  _arch="arm64" ;;
        i386|i686)      _arch="386" ;;
        *)              _die "Unsupported architecture: $(uname -m)" ;;
    esac

    _url="https://github.com/dunstorm/pm2-go/releases/download/v${PM2_GO_VERSION}/pm2-go_linux_${_arch}"
    _bin_real="$SHILL_CORE/bin/pm2-go.bin"
    _wrapper="$SHILL_CORE/bin/pm2-go"
    _pm2_home="$SHILL_CORE/etc/.pm2-go"

    _log "Installing PM2-GO v${PM2_GO_VERSION} (${_arch})..."

    # 1. Download binary to .bin
    _log "Downloading from GitHub Releases..."
    curl -fsSL "$_url" -o "$_bin_real" || _die "Download failed."
    chmod +x "$_bin_real"

    # 2. Prepare HOME directory
    mkdir -p "$_pm2_home" "$_pm2_home/logs" "$_pm2_home/pids"

    # 3. Create Wrapper
    _log "Creating wrapper script..."
    cat <<EOF > "$_wrapper"
#!/bin/sh
# pm2-go wrapper for Shill
export HOME="\$SHILL_CORE/etc"
export PM2_HOME="$_pm2_home"
exec "\$SHILL_CORE/bin/pm2-go.bin" "\$@"
EOF
    chmod +x "$_wrapper"

    _ok "PM2-GO installed successfully (HOME isolated to etc/.pm2-go)."
    "$_wrapper" version 2>/dev/null || true
}

_remove() {
    _log "Removing PM2-GO..."
    rm -f "$SHILL_CORE/bin/pm2-go" "$SHILL_CORE/bin/pm2-go.bin"
    rm -rf "$SHILL_CORE/etc/.pm2-go"
    _ok "PM2-GO removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
