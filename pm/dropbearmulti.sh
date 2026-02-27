#!/bin/sh
# ==============================================================================
# Shill PM Installer: dropbearmulti
# Downloads static dropbearmulti binary from ryanwoodsmall/static-binaries
# ==============================================================================

set -e

_log()  { printf '[shill:dropbearmulti] %s\n' "$*"; }
_die()  { printf '[shill:dropbearmulti] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:dropbearmulti] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    case "$(uname -m)" in
        x86_64|amd64)   _arch="x86_64" ;;
        aarch64|arm64)  _arch="aarch64" ;;
        *)              _die "Unsupported architecture: $(uname -m)" ;;
    esac

    _url="https://raw.githubusercontent.com/ryanwoodsmall/static-binaries/master/${_arch}/dropbearmulti"
    _target="$SHILL_CORE/bin/dropbearmulti"

    _log "Installing dropbearmulti (${_arch})..."
    curl -fsSL "$_url" -o "$_target" || _die "Download failed."
    chmod +x "$_target"

    # Create applet symlinks
    for _applet in dbclient dropbearkey dropbearconvert dropbear; do
        ln -sf "dropbearmulti" "$SHILL_CORE/bin/$_applet"
    done

    _ok "dropbearmulti installed (with symlinks: dbclient, dropbearkey, etc.)."
    "$SHILL_CORE/bin/dropbearmulti" --version 2>/dev/null || true
}

_remove() {
    _log "Removing dropbearmulti..."
    rm -f "$SHILL_CORE/bin/dropbearmulti"
    rm -f "$SHILL_CORE/bin/dbclient" "$SHILL_CORE/bin/dropbearkey" \
          "$SHILL_CORE/bin/dropbearconvert" "$SHILL_CORE/bin/dropbear"
    _ok "dropbearmulti removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
