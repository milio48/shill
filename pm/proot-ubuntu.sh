#!/bin/sh
# ==============================================================================
# Shill PM Installer: Ubuntu Base (via PRoot)
# Sets up a lightweight Ubuntu 24.04 environment without root privileges.
# ==============================================================================

set -e


_log()  { printf '[shill:proot-ubuntu] %s\n' "$*"; }
_die()  { printf '[shill:proot-ubuntu] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:proot-ubuntu] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

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
    _log "Detecting latest Ubuntu 24.04 point release..."
    UBUNTU_VERSION=$(curl -fsSL "$_release_url/SHA256SUMS" | grep -o "ubuntu-base-24\.04\.[0-9]-base-${_ubuntu_arch}.tar.gz" | head -n 1 | cut -d- -f3)
    
    [ -z "$UBUNTU_VERSION" ] && _die "Could not detect latest Ubuntu version."
    _log "Latest version detected: $UBUNTU_VERSION"

    _rootfs_url="${_release_url}ubuntu-base-${UBUNTU_VERSION}-base-${_ubuntu_arch}.tar.gz"
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
        
        _log "Extracting RootFS to lib/proot-ubuntu..."
        mkdir -p "$_ubuntu_root"
        tar -xf "$_tgz" -C "$_ubuntu_root" || _die "Extraction failed."
        rm -f "$_tgz"

        # Setup DNS inside container
        _log "Configuring DNS (resolv.conf)..."
        printf "nameserver 8.8.8.8\nnameserver 8.8.4.4\n" > "$_ubuntu_root/etc/resolv.conf"

        # --- Fine-tuning (GPG Fix, Locales & Cleanup) ---
        _log "Fine-tuning system (Locale & Cleanup)..."
        # We run this via PRoot to initialize the environment properly.
        # 1. We allow insecure update to fetch the list despite missing keys.
        # 2. We install ubuntu-keyring without authentication to fix keys.
        # 3. We then do a proper secure update.
        "$_proot_bin" -r "$_ubuntu_root" -0 -b /dev -b /sys -b /proc /bin/sh -c "
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowDowngradeToInsecureRepositories=true || true
            apt-get install -y --allow-unauthenticated -o APT::Get::AllowUnauthenticated=true ubuntu-keyring &&
            apt-get update &&
            apt-get install -y locales && 
            locale-gen en_US.UTF-8 && 
            apt-get clean && 
            rm -rf /var/lib/apt/lists/*
        " || _log "⚠️ Fine-tuning failed (non-critical). You can fix locales later."
    else
        _log "Ubuntu RootFS already exists at lib/proot-ubuntu. Skipping download."
    fi

    # 3. Create proot-ubuntu Wrapper
    _log "Creating 'proot-ubuntu' command wrapper..."
    cat <<EOF > "$_ubuntu_wrapper"
#!/bin/sh
# Ubuntu PRoot wrapper for Shill
# Usage: proot-ubuntu [command]

_ROOT="$_ubuntu_root"
_PROOT="$_proot_bin"

# Fallback for SHILL_CORE if not in environment
[ -z "$SHILL_CORE" ] && export SHILL_CORE=$(dirname "$(dirname "$(readlink -f "$0")")")

if [ ! -d "\$_ROOT" ]; then
    echo "❌ Ubuntu RootFS not found. Please reinstall."
    exit 1
fi

# Environment Isolation (Detach from Shill ecosystem)
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
unset SHILL_CORE
unset SHILL_SESSION

# Set Locale & Prompt
export LANG=en_US.UTF-8
export PS1='\u@\h:\w\$ '
export TERM=xterm-256color

# Note: -0 maps current user to root inside container
# -b binds host directories for system access
exec "\$_PROOT" \\
    -r "\$_ROOT" \\
    -0 -w /root \\
    -b /dev -b /sys -b /proc \\
    -b /tmp \\
    /bin/bash "\$@"
EOF
    chmod +x "$_ubuntu_wrapper"

    _ok "proot-ubuntu installed successfully."
    _log "Type 'proot-ubuntu' to enter the environment."
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
