#!/bin/sh
# ==============================================================================
# Shill PM Installer: cloudflared
# Cloudflare Tunnel client. The upstream recommendation is "brew install
# cloudflared", which needs a package manager/root. In a non-root userspace we
# fetch the prebuilt static binary instead.
# Installed to: $SHILL_CORE/bin/cloudflared
# ==============================================================================

set -e

CLOUDFLARED_FALLBACK_TAG="2026.9.3"

_log()  { printf '[shill:cloudflared] %s\n' "$*"; }
_die()  { printf '[shill:cloudflared] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:cloudflared] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_append_env() {
    _env_file="$SHILL_CORE/etc/env.sh"
    mkdir -p "$SHILL_CORE/etc"
    [ -f "$_env_file" ] || printf '# Shill environment contract (managed automatically by pm/*.sh)\n' > "$_env_file"
    grep -q '>>> shill:cloudflared >>>' "$_env_file" && return 0
    cat <<EOF >> "$_env_file"

# >>> shill:cloudflared >>>
# Keep the tunnel origin cert inside the core instead of ~/.cloudflared
export TUNNEL_ORIGIN_CERT="$SHILL_CORE/etc/cloudflared/cert.pem"
# <<< shill:cloudflared <<<
EOF
}

_install() {
    case "$(uname -m)" in
        x86_64|amd64)        _arch="amd64" ;;
        aarch64|arm64)       _arch="arm64" ;;
        armv7l|armhf)        _arch="armhf" ;;
        armv6l)              _arch="arm" ;;
        i386|i686)           _arch="386" ;;
        *)                   _die "Unsupported architecture: $(uname -m)" ;;
    esac

    # Resolve latest tag for logging/pinning; fall back to the pinned tag.
    _tag="$CLOUDFLARED_FALLBACK_TAG"
    _api=$(curl -fsSL "https://api.github.com/repos/cloudflare/cloudflared/releases/latest" 2>/dev/null | \
        grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)
    [ -n "$_api" ] && _tag="$_api"

    _asset="cloudflared-linux-${_arch}"
    _url="https://github.com/cloudflare/cloudflared/releases/download/${_tag}/${_asset}"
    _target="$SHILL_CORE/bin/cloudflared"

    _log "Installing cloudflared ${_tag} (${_arch})..."

    _log "Downloading from GitHub Releases..."
    if ! curl -fsSL "$_url" -o "$_target"; then
        _log "Versioned URL failed, trying the 'latest' alias..."
        curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/${_asset}" -o "$_target" || _die "Download failed."
    fi
    chmod +x "$_target"

    mkdir -p "$SHILL_CORE/etc/cloudflared"
    _append_env

    _ok "cloudflared installed successfully."
    "$_target" --version
}

_remove() {
    _log "Removing cloudflared..."
    rm -f "$SHILL_CORE/bin/cloudflared"
    if [ -f "$SHILL_CORE/etc/env.sh" ]; then
        sed -i '/# >>> shill:cloudflared >>>/,/# <<< shill:cloudflared <<</d' "$SHILL_CORE/etc/env.sh" 2>/dev/null || true
    fi
    _ok "cloudflared removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
