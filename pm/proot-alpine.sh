#!/bin/sh
# ==============================================================================
# Shill PM Installer: Alpine Linux (via PRoot)
# Sets up a lightweight Alpine environment without root privileges.
# The wrapper keeps the current directory visible and exposes `add`/`update`
# pass-through commands so it feels like a native shell.
# ==============================================================================

set -e

ALPINE_VERSION="3.21.3"

_log()  { printf '[shill:proot-alpine] %s\n' "$*"; }
_die()  { printf '[shill:proot-alpine] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:proot-alpine] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_verify_sha256() {
    _file="$1"
    _want="$2"
    if command -v sha256sum >/dev/null 2>&1; then
        _got=$(sha256sum "$_file" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        _got=$(shasum -a 256 "$_file" | awk '{print $1}')
    else
        _log "⚠️  No sha256 tool available; skipping integrity check."
        return 0
    fi
    if [ "$_got" != "$_want" ]; then
        rm -f "$_file"
        _die "Checksum mismatch for $(basename "$_file")."
    fi
    _ok "Checksum verified."
}

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

    # Version: custom > Alpine latest-stable > pinned fallback (with sha256)
    if [ -n "${SHILL_PKG_VERSION:-}" ]; then
        ALPINE_VERSION="${SHILL_PKG_VERSION#v}"
        _base="https://dl-cdn.alpinelinux.org/alpine/v$(echo "$ALPINE_VERSION" | cut -d. -f1,2)"
    else
        _base="https://dl-cdn.alpinelinux.org/alpine/latest-stable"
    fi
    _sha=""
    _meta=$(curl -fsSL "${_base}/releases/${_alpine_arch}/latest-releases.yaml" 2>/dev/null || true)
    if [ -n "$_meta" ]; then
        _mv=$(printf '%s\n' "$_meta" | sed -n 's/^ *file: alpine-minirootfs-\([0-9][0-9.]*\)-.*/\1/p' | head -n 1)
        _sha=$(printf '%s\n' "$_meta" | awk '/^ *flavor: alpine-minirootfs/{f=1} f && /^ *sha256:/{sub(/.*sha256:[ ]*/,""); print; exit}')
        if [ -z "${SHILL_PKG_VERSION:-}" ] && [ -n "$_mv" ]; then
            ALPINE_VERSION="$_mv"
        fi
        [ "$_mv" = "$ALPINE_VERSION" ] || _sha=""
    fi
    _rootfs_url="${_base}/releases/${_alpine_arch}/alpine-minirootfs-${ALPINE_VERSION}-${_alpine_arch}.tar.gz"

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
        if [ -n "$_sha" ]; then
            _verify_sha256 "$_tgz" "$_sha"
        else
            _log "⚠️  No checksum available for Alpine ${ALPINE_VERSION}; skipping verification."
        fi

        _log "Extracting RootFS to lib/proot-alpine..."
        mkdir -p "$_alpine_root"
        tar -xf "$_tgz" -C "$_alpine_root" || _die "Extraction failed."
        rm -f "$_tgz"

        # Ensure essential directories exist
        mkdir -p "$_alpine_root/root" "$_alpine_root/tmp"

        # DNS: mirror the host so package installs work during setup
        _log "Configuring DNS (resolv.conf)..."
        if [ -f /etc/resolv.conf ]; then
            cp /etc/resolv.conf "$_alpine_root/etc/resolv.conf"
        else
            printf "nameserver 8.8.8.8\nnameserver 8.8.4.4\n" > "$_alpine_root/etc/resolv.conf"
        fi

        # --- Optimization (Packages & Cleanup) ---
        _log "Optimizing system (Packages & Cleanup)..."
        "$_proot_bin" -r "$_alpine_root" -0 -b /dev -b /sys -b /proc /bin/sh -c "
            apk update &&
            apk upgrade &&
            apk add --no-cache bash ca-certificates coreutils shadow-login &&
            rm -rf /usr/share/man /usr/share/doc /var/cache/apk/*
        " || _log "⚠️ Optimization failed (non-critical)."
    else
        _log "Alpine RootFS already exists at lib/proot-alpine. Skipping download."
    fi

    # 3. Create proot-alpine Wrapper
    _log "Creating 'proot-alpine' command wrapper..."
    cat <<'WRAP' > "$_alpine_wrapper"
#!/bin/sh
# Alpine PRoot wrapper for Shill
#   proot-alpine                 -> interactive shell (keeps current directory)
#   proot-alpine <cmd> [args]    -> run a command inside Alpine
#   proot-alpine add <pkg>...    -> apk add
#   proot-alpine update          -> apk update && apk upgrade

_ROOT="__ROOT__"
_PROOT="__PROOT__"

if [ ! -d "$_ROOT" ]; then
    echo "❌ Alpine RootFS not found. Please reinstall." >&2
    exit 1
fi

# Detach from the Shill ecosystem
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
unset SHILL_CORE
unset SHILL_SESSION

# Identity & terminal
export TERM="${TERM:-xterm-256color}"
export LANG="C.UTF-8"
export PS1='\u@\h:\w\$ '

# Put proot's temp files on RAM when possible (noticeably faster)
if [ -d /dev/shm ] && [ -w /dev/shm ]; then
    export PROOT_TMP_DIR=/dev/shm
fi

_SHELL="/bin/sh"
[ -x "$_ROOT/bin/bash" ] && _SHELL="/bin/bash"

# Convenience subcommands
case "${1:-}" in
    add|install)
        shift
        [ $# -gt 0 ] || { echo "usage: $0 add <pkg>..." >&2; exit 1; }
        set -- /sbin/apk add "$@"
        ;;
    update)
        set -- /bin/sh -c 'apk update && apk upgrade'
        ;;
    run)
        shift
        [ $# -gt 0 ] || { echo "usage: $0 run <cmd>..." >&2; exit 1; }
        ;;
esac

# Default: interactive shell
[ $# -eq 0 ] && set -- "$_SHELL"

# Keep the current directory visible inside the guest
_WORKDIR="/root"
if [ "$PWD" != "/" ] && [ -d "$PWD" ]; then
    _WORKDIR="$PWD"
fi

# Build proot arguments, keeping the guest command last.
# (Each 'set --' prepends options, so quoting of paths is preserved.)
set -- -r "$_ROOT" -0 -w "$_WORKDIR" -b /dev -b /sys -b /proc -b /tmp "$@"
[ -f /etc/resolv.conf ] && set -- -b /etc/resolv.conf "$@"
[ -f /etc/hosts ] && set -- -b /etc/hosts "$@"
[ "$_WORKDIR" != "/root" ] && set -- -b "$_WORKDIR" "$@"
if [ -n "$HOME" ] && [ "$HOME" != "/" ] && [ "$HOME" != "$_WORKDIR" ] && [ -d "$HOME" ]; then
    set -- -b "$HOME" "$@"
fi

exec "$_PROOT" "$@"
WRAP
    sed -i -e "s|__ROOT__|$_alpine_root|g" -e "s|__PROOT__|$_proot_bin|g" "$_alpine_wrapper"
    chmod +x "$_alpine_wrapper"

    _ok "proot-alpine installed successfully."
    _log "Type 'proot-alpine' to enter, 'proot-alpine add <pkg>' to install packages."
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
