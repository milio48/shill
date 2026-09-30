#!/bin/sh
# ==============================================================================
# Shill PM Installer: Ubuntu Base (via PRoot)
# Sets up a lightweight Ubuntu 24.04 environment without root privileges.
# The wrapper keeps the current directory visible and exposes apt pass-through
# commands so it feels like a native shell.
# ==============================================================================

set -e

_log()  { printf '[shill:proot-ubuntu] %s\n' "$*"; }
_die()  { printf '[shill:proot-ubuntu] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:proot-ubuntu] ✅ %s\n' "$*"; }

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
            _ubuntu_arch="amd64"
            _proot_url="https://proot.gitlab.io/proot/bin/proot"
            ;;
        aarch64|arm64)
            _ubuntu_arch="arm64"
            _proot_url="https://github.com/proot-me/proot-static-builds/raw/master/bin/proot-arm64"
            ;;
        *)              _die "Unsupported architecture: $_arch_raw" ;;
    esac

    # Dynamic version detection for 24.04 (Noble) latest point release
    _release_url="http://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/"
    _sums=$(curl -fsSL "$_release_url/SHA256SUMS" 2>/dev/null || true)

    if [ -n "${SHILL_PKG_VERSION:-}" ]; then
        UBUNTU_VERSION="${SHILL_PKG_VERSION#v}"
        _log "Pinned Ubuntu version: $UBUNTU_VERSION"
    else
        _log "Detecting latest Ubuntu 24.04 point release..."
        UBUNTU_VERSION=$(printf '%s\n' "$_sums" | grep -o "ubuntu-base-24\.04\.[0-9]-base-${_ubuntu_arch}.tar.gz" | head -n 1 | cut -d- -f3)
    fi

    [ -z "$UBUNTU_VERSION" ] && _die "Could not detect latest Ubuntu version."
    _log "Ubuntu version: $UBUNTU_VERSION"

    _rootfs_file="ubuntu-base-${UBUNTU_VERSION}-base-${_ubuntu_arch}.tar.gz"
    _sha=$(printf '%s\n' "$_sums" | awk -v f="$_rootfs_file" 'index($0, f) { print $1; exit }')
    _rootfs_url="${_release_url}${_rootfs_file}"
    _lib_dir="$SHILL_CORE/lib"
    _ubuntu_root="$_lib_dir/proot-ubuntu"
    _cache="$SHILL_CORE/cache"
    _tgz="$_cache/ubuntu-rootfs.tar.gz"
    _proot_bin="$SHILL_CORE/bin/proot"
    _ubuntu_wrapper="$SHILL_CORE/bin/proot-ubuntu"

    _log "Installing Ubuntu Base ${UBUNTU_VERSION} (${_ubuntu_arch}) via PRoot..."

    # 1. Download & Prepare PRoot
    if [ ! -f "$_proot_bin" ]; then
        _log "Downloading PRoot binary..."
        curl -fsSL "$_proot_url" -o "$_proot_bin" || _die "PRoot download failed."
        chmod +x "$_proot_bin"
    fi

    # 2. Download & Extract RootFS
    if [ ! -d "$_ubuntu_root" ]; then
        _log "Downloading Ubuntu RootFS (approx 30MB)..."
        curl -fsSL "$_rootfs_url" -o "$_tgz" || _die "RootFS download failed."
        if [ -n "$_sha" ]; then
            _verify_sha256 "$_tgz" "$_sha"
        else
            _log "⚠️  No checksum available for Ubuntu ${UBUNTU_VERSION}; skipping verification."
        fi

        _log "Extracting RootFS to lib/proot-ubuntu..."
        mkdir -p "$_ubuntu_root"
        tar -xf "$_tgz" -C "$_ubuntu_root" || _die "Extraction failed."
        rm -f "$_tgz"

        # DNS: mirror the host so package installs work during setup
        _log "Configuring DNS (resolv.conf)..."
        if [ -f /etc/resolv.conf ]; then
            cp /etc/resolv.conf "$_ubuntu_root/etc/resolv.conf"
        else
            printf "nameserver 8.8.8.8\nnameserver 8.8.4.4\n" > "$_ubuntu_root/etc/resolv.conf"
        fi

        # --- Fine-tuning (GPG Fix, Locales & Cleanup) ---
        _log "Fine-tuning system (Locale & Cleanup)..."
        # 1. Insecure update to fetch the list despite missing keys.
        # 2. Install ubuntu-keyring unauthenticated to fix keys.
        # 3. Proper secure update, locales, then strip docs/caches.
        "$_proot_bin" -r "$_ubuntu_root" -0 -b /dev -b /sys -b /proc /bin/sh -c "
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowDowngradeToInsecureRepositories=true || true
            apt-get install -y --allow-unauthenticated -o APT::Get::AllowUnauthenticated=true ubuntu-keyring &&
            apt-get update &&
            apt-get install -y locales &&
            locale-gen en_US.UTF-8 &&
            apt-get clean &&
            rm -rf /var/lib/apt/lists/* /usr/share/man /usr/share/doc
        " || _log "⚠️ Fine-tuning failed (non-critical). You can fix locales later."
    else
        _log "Ubuntu RootFS already exists at lib/proot-ubuntu. Skipping download."
    fi

    # 3. Create proot-ubuntu Wrapper
    _log "Creating 'proot-ubuntu' command wrapper..."
    cat <<'WRAP' > "$_ubuntu_wrapper"
#!/bin/sh
# Ubuntu PRoot wrapper for Shill
#   proot-ubuntu                 -> interactive shell (keeps current directory)
#   proot-ubuntu <cmd> [args]    -> run a command inside Ubuntu
#   proot-ubuntu add <pkg>...    -> apt-get install
#   proot-ubuntu update          -> apt-get update && apt-get upgrade

_ROOT="__ROOT__"
_PROOT="__PROOT__"

if [ ! -d "$_ROOT" ]; then
    echo "❌ Ubuntu RootFS not found. Please reinstall." >&2
    exit 1
fi

# Detach from the Shill ecosystem
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
unset SHILL_CORE
unset SHILL_SESSION

# Identity, terminal & non-interactive apt
export TERM="${TERM:-xterm-256color}"
export LANG="en_US.UTF-8"
export DEBIAN_FRONTEND=noninteractive
export PS1='\u@\h:\w\$ '

# Put proot's temp files on RAM when possible (noticeably faster)
if [ -d /dev/shm ] && [ -w /dev/shm ]; then
    export PROOT_TMP_DIR=/dev/shm
fi

# Convenience subcommands
case "${1:-}" in
    add|install)
        shift
        [ $# -gt 0 ] || { echo "usage: $0 add <pkg>..." >&2; exit 1; }
        set -- apt-get install -y "$@"
        ;;
    update)
        set -- /bin/sh -c 'apt-get update && apt-get upgrade -y'
        ;;
    run)
        shift
        [ $# -gt 0 ] || { echo "usage: $0 run <cmd>..." >&2; exit 1; }
        ;;
esac

# Default: interactive shell
[ $# -eq 0 ] && set -- /bin/bash

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
    sed -i -e "s|__ROOT__|$_ubuntu_root|g" -e "s|__PROOT__|$_proot_bin|g" "$_ubuntu_wrapper"
    chmod +x "$_ubuntu_wrapper"

    _ok "proot-ubuntu installed successfully."
    _log "Type 'proot-ubuntu' to enter, 'proot-ubuntu add <pkg>' to install packages."
}

_remove() {
    _log "Removing Ubuntu environment..."
    rm -rf "$SHILL_CORE/lib/proot-ubuntu"
    rm -f "$SHILL_CORE/bin/proot-ubuntu"
    _ok "proot-ubuntu removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
