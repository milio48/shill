#!/bin/sh
# ==============================================================================
# Shill PM Installer: Python (Astral Standalone)
# Picks the glibc or musl build to match the host, so pip resolves prebuilt
# wheels instead of compiling from source. Wires pip/uv caches into SHILL_CORE
# and installs uv (fast pip/venv replacement).
# Installed to: $SHILL_CORE/lib/python
# Binaries symlinked to: $SHILL_CORE/bin/python3
# ==============================================================================

set -e

# Version and Tag Configuration (primary first, fallback second)
# 20250212 misses aarch64-musl; 20260929 ships gnu+musl for both x86_64 and
# aarch64, so it is the primary and the older tag is the safety net.
PY_BUILDS="20260929:3.13.15 20250212:3.13.2"
UV_VERSION="0.6.3"

# Custom version: shill install python@3.13.15 (tries known tags) or
# shill install python@20260929:3.13.15 (explicit tag:version)
if [ -n "${SHILL_PKG_VERSION:-}" ]; then
    _pv="${SHILL_PKG_VERSION#v}"
    case "$_pv" in
        *:*) PY_BUILDS="$_pv" ;;
        *)   PY_BUILDS="20260929:$_pv 20250212:$_pv" ;;
    esac
fi

_log()  { printf '[shill:python] %s\n' "$*"; }
_die()  { printf '[shill:python] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:python] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

# --- libc detection: glibc hosts get manylinux wheels, musl hosts get musllinux.
# Forcing musl everywhere (the old behaviour) is what made pip build from source.
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
    grep -q '>>> shill:python >>>' "$_env_file" && return 0
    cat <<EOF >> "$_env_file"

# >>> shill:python >>>
export PIP_CONFIG_FILE="$SHILL_CORE/etc/pip.conf"
export UV_PYTHON_INSTALL_DIR="$SHILL_CORE/lib/uv/python"
export UV_CACHE_DIR="$SHILL_CORE/cache/uv"
export UV_TOOL_DIR="$SHILL_CORE/lib/uv/tools"
export UV_TOOL_BIN_DIR="$SHILL_CORE/bin"
export UV_LINK_MODE="copy"
# <<< shill:python <<<
EOF
}

_check_headers() {
    # C extensions need Python.h + pyconfig.h. The astral install_only build
    # ships both (verified), so this is a safety net rather than a dependency.
    _inc_dir=$("$SHILL_CORE/bin/python3" -c 'import sysconfig; print(sysconfig.get_paths()["include"])' 2>/dev/null || true)
    if [ -n "$_inc_dir" ] && [ -f "$_inc_dir/Python.h" ] && [ -f "$_inc_dir/pyconfig.h" ]; then
        return 0
    fi
    _log "⚠️  Python headers (Python.h / pyconfig.h) not found in ${_inc_dir:-<unknown>}."
    _log "    C extensions and source builds would fail. Try reinstalling:"
    _log "    shill remove python && shill install python"
}

_hint_toolchain() {
    # A C compiler is only needed when a package has no prebuilt wheel.
    [ -x "$SHILL_CORE/bin/zig" ] && return 0
    command -v cc >/dev/null 2>&1 && return 0
    command -v gcc >/dev/null 2>&1 && return 0
    command -v clang >/dev/null 2>&1 && return 0
    _log "No C compiler found. If a package ships only source (no wheel):"
    _log "    shill install toolchain"
}

_install() {
    _libc="$(_detect_libc)"
    _log "Detected libc: $_libc"

    # Detect architecture (astral ships x86_64 + aarch64 standalone builds)
    _arch_raw=$(uname -m)
    case "$_arch_raw" in
        x86_64|amd64)   _cpu="x86_64" ;;
        aarch64|arm64)  _cpu="aarch64" ;;
        *)              _die "Unsupported architecture: $_arch_raw" ;;
    esac

    _target="${_cpu}-unknown-linux-${_libc}"

    # Default: follow the newest python-build-standalone release. Pick the
    # highest 3.x build that has an asset for this target.
    if [ -z "${SHILL_PKG_VERSION:-}" ]; then
        _rel=$(curl -fsSL "https://api.github.com/repos/astral-sh/python-build-standalone/releases/latest" 2>/dev/null \
            | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [ -n "$_rel" ]; then
            _best=$(curl -fsSL "https://api.github.com/repos/astral-sh/python-build-standalone/releases/tags/${_rel}" 2>/dev/null \
                | grep -oE "cpython-3\.[0-9]+\.[0-9]+\+${_rel}-${_target}-install_only\.tar\.gz" \
                | sed -E 's/^cpython-(3\.[0-9]+\.[0-9]+)\+.*/\1/' \
                | sort -u -t. -k1,1n -k2,2n -k3,3n | tail -n 1)
            [ -n "$_best" ] && PY_BUILDS="${_rel}:${_best}"
        fi
    fi

    _cache="$SHILL_CORE/cache"
    _lib_dir="$SHILL_CORE/lib"
    _py_root="$_lib_dir/python"

    # Try each pinned build until one provides the asset for this target.
    # Format: cpython-<ver>+<tag>-<target>-install_only.tar.gz
    _tgz=""
    _py_ver=""
    for _pair in $PY_BUILDS; do
        _tag="${_pair%%:*}"
        _ver="${_pair#*:}"
        _file="cpython-${_ver}+${_tag}-${_target}-install_only.tar.gz"
        _url="https://github.com/astral-sh/python-build-standalone/releases/download/${_tag}/${_file}"
        _log "Trying portable Python ${_ver} (${_tag}, ${_libc})..."
        if curl -fsSL "$_url" -o "$_cache/$_file"; then
            _tgz="$_cache/$_file"
            _py_ver="$_ver"
            break
        fi
        rm -f "$_cache/$_file"
    done
    [ -n "$_tgz" ] || _die "No portable Python build available for ${_target}."

    _log "Installing Python ${_py_ver} (Astral, ${_libc})..."

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

    # --- pip config: keep cache inside the core, prefer wheels over source ---
    _log "Writing pip config..."
    mkdir -p "$SHILL_CORE/etc" "$SHILL_CORE/cache/pip"
    cat <<EOF > "$SHILL_CORE/etc/pip.conf"
[global]
cache-dir = $SHILL_CORE/cache/pip
prefer-binary = true
disable-pip-version-check = true
EOF

    # --- uv: ultra-fast pip/venv replacement (latest, pinned fallback) ---
    _uv_rel=$(curl -fsSL "https://api.github.com/repos/astral-sh/uv/releases/latest" 2>/dev/null \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    [ -n "$_uv_rel" ] && UV_VERSION="$_uv_rel"
    _log "Installing uv ${UV_VERSION} (Fast Python Package Manager)..."
    _uv_file="uv-${_target}.tar.gz"
    _uv_url="https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${_uv_file}"
    if curl -fsSL "$_uv_url" -o "$_cache/$_uv_file"; then
        _uv_tmp="$_cache/uv_extract"
        rm -rf "$_uv_tmp"
        mkdir -p "$_uv_tmp"
        # Newer archives are nested (uv-<target>/uv); older ones are flat.
        tar -xzf "$_cache/$_uv_file" -C "$_uv_tmp" --strip-components=1 "uv-${_target}/uv" "uv-${_target}/uvx" 2>/dev/null || \
        tar -xzf "$_cache/$_uv_file" -C "$_uv_tmp" 2>/dev/null || true
        _uv_bin=$(find "$_uv_tmp" -type f -name uv 2>/dev/null | head -n 1)
        _uvx_bin=$(find "$_uv_tmp" -type f -name uvx 2>/dev/null | head -n 1)
        if [ -n "$_uv_bin" ]; then
            cp -f "$_uv_bin" "$SHILL_CORE/bin/uv"
            chmod +x "$SHILL_CORE/bin/uv"
            [ -n "$_uvx_bin" ] && cp -f "$_uvx_bin" "$SHILL_CORE/bin/uvx" && chmod +x "$SHILL_CORE/bin/uvx"
            _ok "uv and uvx installed to bin/."
        else
            _log "Note: uv binary not found in archive."
        fi
        rm -rf "$_uv_tmp"
        rm -f "$_cache/$_uv_file"
    else
        _log "Note: Could not download uv."
    fi

    # Create a profile hook so that pip global binaries are in PATH
    mkdir -p "$SHILL_CORE/etc/profile.d"
    echo 'export PATH="$SHILL_CORE/lib/python/bin:$PATH"' > "$SHILL_CORE/etc/profile.d/python.sh"
    _append_env

    _check_headers
    _hint_toolchain
    _ok "Python installed successfully (${_libc} wheels)."
    "$SHILL_CORE/bin/python3" --version
}

_remove() {
    _log "Removing Python..."
    rm -rf "$SHILL_CORE/lib/python" "$SHILL_CORE/lib/uv"
    rm -f "$SHILL_CORE/bin/python" "$SHILL_CORE/bin/python3" \
          "$SHILL_CORE/bin/pip" "$SHILL_CORE/bin/pip3" \
          "$SHILL_CORE/bin/uv" "$SHILL_CORE/bin/uvx" \
          "$SHILL_CORE/etc/pip.conf" "$SHILL_CORE/etc/profile.d/python.sh"
    if [ -f "$SHILL_CORE/etc/env.sh" ]; then
        sed -i '/# >>> shill:python >>>/,/# <<< shill:python <<</d' "$SHILL_CORE/etc/env.sh" 2>/dev/null || true
    fi
    _ok "Python removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
