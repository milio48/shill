#!/bin/sh
# ==============================================================================
# Shill PM Installer: Alpine Linux (via PRoot)
# Sets up a lightweight Alpine Linux environment without root privileges.
# ==============================================================================

set -e

ALPINE_VERSION="3.21.3"

_log()  { printf '[shill:proot-alpine] %s\n' "$*"; }
_die()  { printf '[shill:proot-alpine] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:proot-alpine] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    # Detect architecture
    _arch_raw=$(uname -m)
    case "$_arch_raw" in
        x86_64|amd64)   
            _alpine_arch="x86_64" 
            _proot_url="https://proot.gitlab.io/proot/bin/proot"
            ;;
        aarch64|arm64)  
            _alpine_arch="aarch64" 
            _proot_url="https://github.com/proot-me/proot-static-builds/raw/master/bin/proot-arm64"
            ;;
        *)              _die "Unsupported architecture: $_arch_raw" ;;
    esac

    _v_major_minor=$(echo "$ALPINE_VERSION" | cut -d. -f1,2)
    _rootfs_url="https://dl-cdn.alpinelinux.org/alpine/v${_v_major_minor}/releases/${_alpine_arch}/alpine-minirootfs-${ALPINE_VERSION}-${_alpine_arch}.tar.gz"
    
    _lib_dir="$SHILL_CORE/lib"
    _alpine_root="$_lib_dir/proot-alpine"
    _cache="$SHILL_CORE/cache"
    _tgz="$_cache/alpine-rootfs.tar.gz"
    _proot_bin="$SHILL_CORE/bin/proot"
    _alpine_wrapper="$SHILL_CORE/bin/proot-alpine"

    _log "Installing Alpine Linux ${ALPINE_VERSION} (${_alpine_arch}) via PRoot..."

    # 1. Download & Prepare PRoot
    if [ ! -f "$_proot_bin" ]; then
        _log "Downloading PRoot binary..."
        curl -fsSL "$_proot_url" -o "$_proot_bin" || _die "PRoot download failed."
        chmod +x "$_proot_bin"
    fi

    # 2. Download & Extract RootFS
    if [ ! -d "$_alpine_root" ]; then
        _log "Downloading Alpine RootFS (approx 3MB)..."
        curl -fsSL "$_rootfs_url" -o "$_tgz" || _die "RootFS download failed."
        
        _log "Extracting RootFS to lib/proot-alpine..."
        mkdir -p "$_alpine_root"
        tar -xf "$_tgz" -C "$_alpine_root" || _die "Extraction failed."
        rm -f "$_tgz"

        # Setup DNS inside container
        _log "Configuring DNS (resolv.conf)..."
        printf "nameserver 8.8.8.8\nnameserver 8.8.4.4\n" > "$_alpine_root/etc/resolv.conf"

        # --- Optimization (Packages & Cleanup) ---
        _log "Optimizing system (Packages & Cleanup)..."
        "$_proot_bin" -r "$_alpine_root" -0 -b /dev -b /sys -b /proc /bin/sh -c "
            apk update && 
            apk upgrade && 
            apk add --no-cache bash ca-certificates coreutils shadow-login &&
            rm -rf /var/cache/apk/*
        " || _log "⚠️ Optimization failed (non-critical)."
    else
        _log "Alpine RootFS already exists at lib/proot-alpine. Skipping download."
    fi

    # 3. Create proot-alpine Wrapper
    _log "Creating 'proot-alpine' command wrapper..."
    cat <<EOF > "$_alpine_wrapper"
#!/bin/sh
# Alpine PRoot wrapper for Shill
# Usage: proot-alpine [command]

_ROOT="$_alpine_root"
_PROOT="$_proot_bin"

if [ ! -d "\$_ROOT" ]; then
    echo "❌ Alpine RootFS not found. Please reinstall."
    exit 1
fi

# Environment Reset (Avoid inheriting Shill prompt)
export PS1='\u@\h:\w\$ '
export TERM=xterm-256color

# Note: -0 maps current user to root inside container
# -b binds host directories for system access
exec "\$_PROOT" \\
    -r "\$_ROOT" \\
    -0 -w /root \\
    -b /dev -b /sys -b /proc \\
    -b /tmp \\
    -b "\$SHILL_CORE:/shill" \\
    /bin/bash "\$@"
EOF
    chmod +x "$_alpine_wrapper"

    _ok "proot-alpine installed successfully."
    _log "Type 'proot-alpine' to enter the environment."
}

_remove() {
    _log "Removing Alpine environment..."
    rm -rf "$SHILL_CORE/lib/proot-alpine"
    rm -f "$SHILL_CORE/bin/proot-alpine"
    _ok "proot-alpine removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
