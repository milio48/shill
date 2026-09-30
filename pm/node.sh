#!/bin/sh
# ==============================================================================
# Shill PM Installer: Node.js
# Downloads official Node.js LTS binary, plus the matching C headers so that
# node-gyp / native addons (node_modules with C++) can build. Wires the npm
# prefix and cache into SHILL_CORE.
# Installed to: $SHILL_CORE/bin/node
# ==============================================================================

set -e

NODE_VERSION="v22.14.0"

_log()  { printf '[shill:node] %s\n' "$*"; }
_die()  { printf '[shill:node] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:node] ✅ %s\n' "$*"; }

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
    grep -q '>>> shill:node >>>' "$_env_file" && return 0
    cat <<EOF >> "$_env_file"

# >>> shill:node >>>
export NPM_CONFIG_USERCONFIG="$SHILL_CORE/etc/npmrc"
export NPM_CONFIG_CACHE="$SHILL_CORE/cache/npm"
export NPM_CONFIG_PREFIX="$SHILL_CORE"
export npm_config_prefix="$SHILL_CORE"
export NODE_REPL_HISTORY="$SHILL_CORE/cache/node_repl_history"
# <<< shill:node <<<
EOF
}

_hint_toolchain() {
    # Only needed to compile native addons (node-gyp).
    [ -x "$SHILL_CORE/bin/zig" ] && return 0
    command -v cc >/dev/null 2>&1 && return 0
    command -v gcc >/dev/null 2>&1 && return 0
    command -v clang >/dev/null 2>&1 && return 0
    _log "No C compiler found. If a package needs a native addon (node-gyp):"
    _log "    shill install toolchain"
}

_install() {
    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)   _arch="x64" ;;
        aarch64|arm64)  _arch="arm64" ;;
        armv7l)         _arch="armv7l" ;;
        *)              _die "Unsupported architecture: $(uname -m)" ;;
    esac

    # Official Node binaries are dynamically linked against glibc.
    if [ "$(_detect_libc)" = "musl" ]; then
        _log "⚠️  Host uses musl libc; official Node builds target glibc and may not run."
        _log "    If it fails, use: shill install proot-alpine (or proot-ubuntu)."
    fi

    _tarball="node-${NODE_VERSION}-linux-${_arch}.tar.xz"
    _url="https://nodejs.org/dist/${NODE_VERSION}/${_tarball}"
    _headers="node-${NODE_VERSION}-headers.tar.gz"
    _cache="$SHILL_CORE/cache"
    _target="$_cache/$_tarball"
    _extract="$_cache/node-${NODE_VERSION}-linux-${_arch}"

    _log "Installing Node.js ${NODE_VERSION} (${_arch})..."

    # Download
    _log "Downloading from nodejs.org..."
    curl -fsSL "$_url" -o "$_target" || _die "Download failed."

    # Ensure an xz decompressor exists (host may only have busybox without xz)
    _xz_cmd=""
    command -v xz >/dev/null 2>&1     && _xz_cmd="xz -dc"
    [ -z "$_xz_cmd" ] && command -v unxz >/dev/null 2>&1 && _xz_cmd="unxz -c"
    if [ -z "$_xz_cmd" ] && "$SHILL_CORE/bin/busybox" xz -h >/dev/null 2>&1; then
        _xz_cmd="$SHILL_CORE/bin/busybox xz -dc"
    fi
    if [ -z "$_xz_cmd" ]; then
        _log "No xz decompressor on host. Fetching static xz..."
        _static_arch=$(case "$(uname -m)" in
            x86_64|amd64) echo x86_64 ;;
            aarch64|arm64) echo aarch64 ;;
            armv7l|armv6l|armhf) echo armhf ;;
            *) echo x86_64 ;;
        esac)
        curl -fsSL "https://raw.githubusercontent.com/ryanwoodsmall/static-binaries/master/${_static_arch}/xz" -o "$SHILL_CORE/bin/xz" && \
            chmod +x "$SHILL_CORE/bin/xz" && _xz_cmd="$SHILL_CORE/bin/xz -dc"
    fi
    [ -z "$_xz_cmd" ] && _die "No xz decompressor available (install xz-utils or provide busybox xz)."

    # Extract
    _log "Extracting..."
    mkdir -p "$_extract"
    $_xz_cmd "$_target" | tar xf - -C "$_cache" 2>/dev/null

    # Install binaries
    _log "Installing binaries..."
    cp "$_extract/bin/node" "$SHILL_CORE/bin/node"
    chmod +x "$SHILL_CORE/bin/node"

    if [ -f "$_extract/bin/npm" ]; then
        # Copy the entire lib/node_modules to SHILL_CORE
        mkdir -p "$SHILL_CORE/lib"
        cp -r "$_extract/lib/node_modules" "$SHILL_CORE/lib/"

        # Create standard symlinks for npm and npx (better compatibility than shell wrappers)
        ln -sf "../lib/node_modules/npm/bin/npm-cli.js" "$SHILL_CORE/bin/npm"
        ln -sf "../lib/node_modules/npm/bin/npx-cli.js" "$SHILL_CORE/bin/npx"

        # Enable Corepack (Yarn, PNPM support out of the box)
        if [ -f "$SHILL_CORE/lib/node_modules/corepack/dist/corepack.js" ]; then
            ln -sf "../lib/node_modules/corepack/dist/corepack.js" "$SHILL_CORE/bin/corepack"
            "$SHILL_CORE/bin/node" "$SHILL_CORE/bin/corepack" enable --install-directory "$SHILL_CORE/bin" || true
        fi
    fi

    # --- Node headers: lets node-gyp build native addons offline ---
    _log "Installing Node headers (for node-gyp)..."
    _hdr_tmp="$_cache/$_headers"
    if curl -fsSL "https://nodejs.org/dist/${NODE_VERSION}/${_headers}" -o "$_hdr_tmp"; then
        rm -rf "$SHILL_CORE/lib/node-gyp"
        mkdir -p "$SHILL_CORE/lib/node-gyp"
        tar -xzf "$_hdr_tmp" -C "$SHILL_CORE/lib/node-gyp" --strip-components=1 || \
            _log "Note: Could not extract Node headers."
        rm -f "$_hdr_tmp"
        [ -d "$SHILL_CORE/lib/node-gyp/include/node" ] && _ok "Node headers installed." || _log "Note: Node headers missing."
    else
        _log "Note: Could not download Node headers."
    fi

    # --- npm config: keep prefix + cache inside the core ---
    _log "Writing npm config..."
    mkdir -p "$SHILL_CORE/etc" "$SHILL_CORE/cache/npm"
    cat <<EOF > "$SHILL_CORE/etc/npmrc"
prefix=$SHILL_CORE
cache=$SHILL_CORE/cache/npm
nodedir=$SHILL_CORE/lib/node-gyp
fund=false
audit=false
update-notifier=false
EOF
    _append_env

    # Cleanup
    rm -rf "$_target" "$_extract"

    _hint_toolchain
    _ok "Node.js ${NODE_VERSION} installed."
    "$SHILL_CORE/bin/node" --version
}

_remove() {
    _log "Removing Node.js..."
    rm -f "$SHILL_CORE/bin/node"
    rm -f "$SHILL_CORE/bin/npm"
    rm -f "$SHILL_CORE/bin/npx"
    rm -f "$SHILL_CORE/bin/corepack"
    rm -rf "$SHILL_CORE/lib/node_modules"
    rm -rf "$SHILL_CORE/lib/node-gyp"
    rm -f "$SHILL_CORE/etc/npmrc"
    if [ -f "$SHILL_CORE/etc/env.sh" ]; then
        sed -i '/# >>> shill:node >>>/,/# <<< shill:node <<</d' "$SHILL_CORE/etc/env.sh" 2>/dev/null || true
    fi
    _ok "Node.js removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
