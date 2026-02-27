#!/bin/sh
# ==============================================================================
# Shill PM Installer: Python (Astral Standalone)
# Downloads a portable, static Python build from astral-sh
# Installed to: $SHILL_CORE/lib/python
# Binaries symlinked to: $SHILL_CORE/bin/python3
# ==============================================================================

set -e

# Version and Tag Configuration
TAG="20250212"
PY_VERSION="3.13.2"

_log()  { printf '[shill:python] %s\n' "$*"; }
_die()  { printf '[shill:python] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:python] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    # Detect architecture
    _arch_raw=$(uname -m)
    case "$_arch_raw" in
        x86_64|amd64)   _target="x86_64-unknown-linux-musl" ;;
        aarch64|arm64)  _target="aarch64-unknown-linux-musl" ;;
        *)              _die "Unsupported architecture: $_arch_raw" ;;
    esac

    # Construct direct download URL (avoids GitHub API rate limits)
    # Format: cpython-3.13.2+20250212-x86_64-unknown-linux-musl-install_only.tar.gz
    _file="cpython-${PY_VERSION}+${TAG}-${_target}-install_only.tar.gz"
    _url="https://github.com/astral-sh/python-build-standalone/releases/download/${TAG}/${_file}"
    
    _cache="$SHILL_CORE/cache"
    _tgz="$_cache/$_file"
    _lib_dir="$SHILL_CORE/lib"
    _py_root="$_lib_dir/python"

    _log "Installing portable Python ${PY_VERSION} (Astral)..."

    # Download
    _log "Downloading from GitHub Releases..."
    curl -fsSL "$_url" -o "$_tgz" || _die "Download failed. Please check if TAG ${TAG} and VERSION ${PY_VERSION} are correct."

    # Prepare lib directory
    mkdir -p "$_lib_dir"
    rm -rf "$_py_root" # Clean install

    # Extract
    _log "Extracting to $SHILL_CORE/lib/python..."
    mkdir -p "$_py_root"
    tar -xzf "$_tgz" -C "$_py_root" --strip-components=1 || _die "Extraction failed."

    # Create symlinks in bin
    _log "Linking binaries to $SHILL_CORE/bin/..."
    ln -sf "../lib/python/bin/python3" "$SHILL_CORE/bin/python3"
    ln -sf "python3" "$SHILL_CORE/bin/python"
    ln -sf "../lib/python/bin/pip3" "$SHILL_CORE/bin/pip3"
    ln -sf "pip3" "$SHILL_CORE/bin/pip"

    # Cleanup
    rm -f "$_tgz"

    _ok "Python installed successfully."
    "$SHILL_CORE/bin/python3" --version
}

_remove() {
    _log "Removing Python..."
    rm -rf "$SHILL_CORE/lib/python"
    rm -f "$SHILL_CORE/bin/python" "$SHILL_CORE/bin/python3" \
          "$SHILL_CORE/bin/pip" "$SHILL_CORE/bin/pip3"
    _ok "Python removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
