#!/bin/sh
# ==============================================================================
# Shill PM Installer: webi (webinstall.dev)
# Installs WebInstall (webi) and envman isolated within SHILL_CORE
# ==============================================================================

set -e

_log()  { printf '[shill:webi] %s\n' "$*"; }
_die()  { printf '[shill:webi] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:webi] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _log "Installing webi (webinstall.dev)..."
    
    # Force webi to install inside SHILL_CORE by hijacking HOME
    # This keeps .local/bin, .local/opt, and .config/envman inside Shill
    export HOME="$SHILL_CORE"
    
    # Download and run the bootstrap script
    curl -sS https://webi.sh/webi | sh || _die "Webi bootstrap failed."

    # Map the webi and envman binaries to our main bin dir for easier access
    if [ -f "$SHILL_CORE/.local/bin/webi" ]; then
        ln -sf "$SHILL_CORE/.local/bin/webi" "$SHILL_CORE/bin/webi"
        ln -sf "$SHILL_CORE/.local/bin/envman" "$SHILL_CORE/bin/envman"
    fi

    # Update .shill_rc if not already patched
    _rc="$SHILL_CORE/.shill_rc"
    if ! grep -q "config/envman/PATH.env" "$_rc"; then
        _log "Patching .shill_rc for webi..."
        printf '\n# webi environment\n[ -f "$SHILL_CORE/.config/envman/PATH.env" ] && . "$SHILL_CORE/.config/envman/PATH.env"\n' >> "$_rc"
    fi

    _ok "webi installed successfully."
    _log "Try: webi jq (or any other package from webinstall.dev)"
}

_remove() {
    _log "Removing webi..."
    rm -f "$SHILL_CORE/bin/webi"
    rm -f "$SHILL_CORE/bin/envman"
    rm -rf "$SHILL_CORE/.local/opt/webi"
    rm -rf "$SHILL_CORE/.config/envman"
    
    # Remove rc entry
    _rc="$SHILL_CORE/.shill_rc"
    sed -i '/# webi environment/,/PATH.env/d' "$_rc" 2>/dev/null || true
    
    _ok "webi removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
