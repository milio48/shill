#!/bin/sh
# ==============================================================================
# Shill PM Installer: Node.js
# Downloads official Node.js LTS binary and installs to $SHILL_CORE/bin/node
# ==============================================================================

set -e

NODE_VERSION="v22.14.0"

_log()  { printf '[shill:node] %s\n' "$*"; }
_die()  { printf '[shill:node] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:node] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)   _arch="x64" ;;
        aarch64|arm64)  _arch="arm64" ;;
        armv7l)         _arch="armv7l" ;;
        *)              _die "Unsupported architecture: $(uname -m)" ;;
    esac

    _tarball="node-${NODE_VERSION}-linux-${_arch}.tar.xz"
    _url="https://nodejs.org/dist/${NODE_VERSION}/${_tarball}"
    _cache="$SHILL_CORE/cache"
    _target="$_cache/$_tarball"
    _extract="$_cache/node-${NODE_VERSION}-linux-${_arch}"

    _log "Installing Node.js ${NODE_VERSION} (${_arch})..."

    # Download
    _log "Downloading from nodejs.org..."
    curl -fsSL "$_url" -o "$_target" || _die "Download failed."

    # Extract
    _log "Extracting..."
    mkdir -p "$_extract"

    # Try xz decompression methods
    if command -v xz >/dev/null 2>&1; then
        xz -dc "$_target" | tar xf - -C "$_cache" 2>/dev/null
    elif command -v unxz >/dev/null 2>&1; then
        unxz -c "$_target" | tar xf - -C "$_cache" 2>/dev/null
    elif busybox xz -h >/dev/null 2>&1; then
        busybox xz -dc "$_target" | tar xf - -C "$_cache" 2>/dev/null
    else
        _die "No xz decompressor found. Install xz-utils or busybox with xz support."
    fi

    # Install binaries
    _log "Installing binaries..."
    cp "$_extract/bin/node" "$SHILL_CORE/bin/node"
    chmod +x "$SHILL_CORE/bin/node"

    # Install npm (optional, as a shell script wrapper it needs node)
    if [ -f "$_extract/bin/npm" ]; then
        # Copy the entire lib/node_modules to SHILL_CORE
        mkdir -p "$SHILL_CORE/lib"
        cp -r "$_extract/lib/node_modules" "$SHILL_CORE/lib/"
        
        # Create npm wrapper
        cat <<'EOF' > "$SHILL_CORE/bin/npm"
#!/bin/sh
exec "$SHILL_CORE/bin/node" "$SHILL_CORE/lib/node_modules/npm/bin/npm-cli.js" "$@"
EOF
        chmod +x "$SHILL_CORE/bin/npm"

        # Create npx wrapper
        cat <<'EOF' > "$SHILL_CORE/bin/npx"
#!/bin/sh
exec "$SHILL_CORE/bin/node" "$SHILL_CORE/lib/node_modules/npm/bin/npx-cli.js" "$@"
EOF
        chmod +x "$SHILL_CORE/bin/npx"
    fi

    # Cleanup
    rm -rf "$_target" "$_extract"

    _ok "Node.js ${NODE_VERSION} installed."
    "$SHILL_CORE/bin/node" --version
}

_remove() {
    _log "Removing Node.js..."
    rm -f "$SHILL_CORE/bin/node"
    rm -f "$SHILL_CORE/bin/npm"
    rm -f "$SHILL_CORE/bin/npx"
    rm -rf "$SHILL_CORE/lib/node_modules"
    _ok "Node.js removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
