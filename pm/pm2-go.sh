#!/bin/sh
# ==============================================================================
# Shill PM Installer: PM2-GO
# Downloads the pm2-go binary (classic CLI) AND the pm2-go-web variant
# (CLI + web dashboard) from GitHub Releases.
# Installed to: $SHILL_CORE/bin/pm2-go and $SHILL_CORE/bin/pm2-go-web
# ==============================================================================

set -e

PM2_GO_VERSION="0.2.0"

# Version: custom > latest release > pinned fallback (leading 'v' stripped)
if [ -z "${SHILL_PKG_VERSION:-}" ] && [ "$1" != "remove" ] && [ "$1" != "uninstall" ]; then
    _latest=$(curl -fsSL "https://api.github.com/repos/dunstorm/pm2-go/releases/latest" 2>/dev/null \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    [ -n "$_latest" ] && PM2_GO_VERSION="${_latest#v}"
fi
[ -n "${SHILL_PKG_VERSION:-}" ] && PM2_GO_VERSION="${SHILL_PKG_VERSION#v}"

_log()  { printf '[shill:pm2-go] %s\n' "$*"; }
_die()  { printf '[shill:pm2-go] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:pm2-go] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

# Build a wrapper that isolates HOME/PM2_HOME inside Shill.
# $1 = wrapper path, $2 = absolute path to the real binary
_make_wrapper() {
    cat <<EOF > "$1"
#!/bin/sh
# pm2-go wrapper for Shill (isolates HOME/PM2_HOME)

mkdir -p "\$SHILL_CORE/etc/.pm2-go/logs" "\$SHILL_CORE/etc/.pm2-go/pids"

export HOME="\$SHILL_CORE/etc"
export PM2_HOME="\$SHILL_CORE/etc/.pm2-go"

exec "$2" "\$@"
EOF
    chmod +x "$1"
}

_install() {
    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)   _arch="amd64" ;;
        aarch64|arm64)  _arch="arm64" ;;
        i386|i686)      _arch="386" ;;
        *)              _die "Unsupported architecture: $(uname -m)" ;;
    esac

    _base="https://github.com/dunstorm/pm2-go/releases/download/v${PM2_GO_VERSION}"
    _bin_real="$SHILL_CORE/bin/pm2-go.bin"
    _bin_web="$SHILL_CORE/bin/pm2-go-web.bin"
    _pm2_home="$SHILL_CORE/etc/.pm2-go"

    _log "Installing PM2-GO v${PM2_GO_VERSION} (${_arch})..."

    # 1. Classic binary (required)
    _log "Downloading pm2-go..."
    curl -fsSL "${_base}/pm2-go_linux_${_arch}" -o "$_bin_real" || _die "Download failed."
    chmod +x "$_bin_real"

    # 2. Web variant (optional, same arch set)
    _web=0
    _log "Downloading pm2-go-web..."
    if curl -fsSL "${_base}/pm2-go-web_linux_${_arch}" -o "$_bin_web"; then
        chmod +x "$_bin_web"
        _web=1
    else
        rm -f "$_bin_web"
        _log "Note: pm2-go-web not available for ${_arch}."
    fi

    # 3. Prepare HOME directory
    mkdir -p "$_pm2_home" "$_pm2_home/logs" "$_pm2_home/pids"

    # 4. Create wrappers
    _log "Creating wrappers..."
    _make_wrapper "$SHILL_CORE/bin/pm2-go" "$_bin_real"
    if [ "$_web" -eq 1 ]; then
        _make_wrapper "$SHILL_CORE/bin/pm2-go-web" "$_bin_web"
    fi

    _ok "PM2-GO v${PM2_GO_VERSION} installed (HOME isolated to etc/.pm2-go)."
    _log "Available commands:"
    _log "  pm2-go      - Classic CLI"
    [ "$_web" -eq 1 ] && _log "  pm2-go-web  - CLI + web dashboard"
    "$SHILL_CORE/bin/pm2-go" version 2>/dev/null || true
}

_remove() {
    _log "Removing PM2-GO..."
    rm -f "$SHILL_CORE/bin/pm2-go" "$SHILL_CORE/bin/pm2-go.bin"
    rm -f "$SHILL_CORE/bin/pm2-go-web" "$SHILL_CORE/bin/pm2-go-web.bin"
    rm -rf "$SHILL_CORE/etc/.pm2-go"
    _ok "PM2-GO removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
