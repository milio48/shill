#!/bin/sh
# ==============================================================================
# Shill PM Installer: Bun
# All-in-one JavaScript runtime + package manager + bundler (single binary).
# Serves as a faster, simpler alternative to the npm toolchain.
# Installed to: $SHILL_CORE/bin/bun
# ==============================================================================

set -e

BUN_FALLBACK_TAG="bun-v1.2.4"

_log()  { printf '[shill:bun] %s\n' "$*"; }
_die()  { printf '[shill:bun] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:bun] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_detect_libc() {
    if command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; then
        echo "musl"
        return
    fi
    for _f in /lib/ld-musl-*.so.1 /lib/*/ld-musl-*.so.1; do
        [ -e "$_f" ] && { echo "musl"; return; }
    done
    echo "gnu"
}

_append_env() {
    _env_file="$SHILL_CORE/etc/env.sh"
    mkdir -p "$SHILL_CORE/etc"
    [ -f "$_env_file" ] || printf '# Shill environment contract (managed automatically by pm/*.sh)\n' > "$_env_file"
    grep -q '>>> shill:bun >>>' "$_env_file" && return 0
    cat <<EOF >> "$_env_file"

# >>> shill:bun >>>
export BUN_INSTALL="$SHILL_CORE"
export BUN_INSTALL_CACHE_DIR="$SHILL_CORE/cache/bun"
# <<< shill:bun <<<
EOF
}

_install() {
    case "$(uname -m)" in
        x86_64|amd64)   _cpu="x64" ;;
        aarch64|arm64)  _cpu="aarch64" ;;
        *)              _die "Unsupported architecture: $(uname -m)" ;;
    esac

    _variant=""
    [ "$(_detect_libc)" = "musl" ] && _variant="-musl"

    # Version: custom (shill install bun@1.4.2) or latest release tag.
    if [ -n "${SHILL_PKG_VERSION:-}" ]; then
        _tag="bun-v${SHILL_PKG_VERSION#v}"
    else
        _tag="$BUN_FALLBACK_TAG"
        _api=$(curl -fsSL "https://api.github.com/repos/oven-sh/bun/releases/latest" 2>/dev/null | \
            grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)
        [ -n "$_api" ] && _tag="$_api"
    fi

    _file="bun-linux-${_cpu}${_variant}.zip"
    _url="https://github.com/oven-sh/bun/releases/download/${_tag}/${_file}"
    _cache="$SHILL_CORE/cache"

    _log "Installing Bun ${_tag} (${_cpu}${_variant})..."

    # Download
    _log "Downloading from GitHub Releases..."
    curl -fsSL "$_url" -o "$_cache/$_file" || _die "Download failed. URL: $_url"

    # Extract (bun ships a .zip; use host unzip or the busybox applet)
    _log "Extracting..."
    _extract="$_cache/bun_extract"
    rm -rf "$_extract"
    mkdir -p "$_extract"

    _unzipped=0
    if command -v unzip >/dev/null 2>&1; then
        unzip -o "$_cache/$_file" -d "$_extract" >/dev/null 2>&1 && _unzipped=1
    fi
    if [ "$_unzipped" -eq 0 ] && "$SHILL_CORE/bin/busybox" unzip -h >/dev/null 2>&1; then
        "$SHILL_CORE/bin/busybox" unzip -o "$_cache/$_file" -d "$_extract" >/dev/null 2>&1 && _unzipped=1
    fi
    [ "$_unzipped" -eq 1 ] || _die "No unzip available. Install 'unzip' or use a busybox with the unzip applet."

    _bun_bin=$(find "$_extract" -type f -name bun 2>/dev/null | head -n 1)
    [ -n "$_bun_bin" ] || _die "bun binary not found in archive."
    cp -f "$_bun_bin" "$SHILL_CORE/bin/bun"
    chmod +x "$SHILL_CORE/bin/bun"

    rm -rf "$_extract"
    rm -f "$_cache/$_file"

    _append_env

    _ok "Bun installed successfully."
    "$SHILL_CORE/bin/bun" --version
}

_remove() {
    _log "Removing Bun..."
    rm -f "$SHILL_CORE/bin/bun"
    if [ -f "$SHILL_CORE/etc/env.sh" ]; then
        sed -i '/# >>> shill:bun >>>/,/# <<< shill:bun <<</d' "$SHILL_CORE/etc/env.sh" 2>/dev/null || true
    fi
    _ok "Bun removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
