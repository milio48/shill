#!/bin/sh
# ==============================================================================
# Shill PM Installer: toolchain (zig + make)
# A portable C/C++ toolchain so pip/npm can build packages that ship no
# prebuilt wheel/binary. zig acts as the compiler (no root, no glibc-dev),
# GNU make and patchelf are installed alongside.
# ==============================================================================

set -e

ZIG_VERSION="0.13.0"

# Version: custom > latest stable (ziglang.org) > pinned fallback
if [ -z "${SHILL_PKG_VERSION:-}" ] && [ "$1" != "remove" ] && [ "$1" != "uninstall" ]; then
    _latest=$(curl -fsSL "https://ziglang.org/download/index.json" 2>/dev/null \
        | grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' | tr -d '"' | sort -u \
        | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)
    [ -n "$_latest" ] && ZIG_VERSION="$_latest"
fi
[ -n "${SHILL_PKG_VERSION:-}" ] && ZIG_VERSION="${SHILL_PKG_VERSION#v}"

_log()  { printf '[shill:toolchain] %s\n' "$*"; }
_die()  { printf '[shill:toolchain] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:toolchain] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

# Directory layout of ryanwoodsmall/static-binaries (matches shill bootstrap)
_static_arch() {
    case "$(uname -m)" in
        x86_64|amd64)        echo "x86_64" ;;
        aarch64|arm64)       echo "aarch64" ;;
        armv7l|armv6l|armhf) echo "armhf" ;;
        *)                   echo "" ;;
    esac
}

# Zig release naming
_zig_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "x86_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        armv7l|armv6l) echo "arm" ;;
        *)             echo "" ;;
    esac
}

_append_env() {
    _env_file="$SHILL_CORE/etc/env.sh"
    mkdir -p "$SHILL_CORE/etc"
    [ -f "$_env_file" ] || printf '# Shill environment contract (managed automatically by pm/*.sh)\n' > "$_env_file"
    grep -q '>>> shill:toolchain >>>' "$_env_file" && return 0
    cat <<EOF >> "$_env_file"

# >>> shill:toolchain >>>
export CC="$SHILL_CORE/bin/zig cc"
export CXX="$SHILL_CORE/bin/zig c++"
export AR="$SHILL_CORE/bin/zig ar"
# <<< shill:toolchain <<<
EOF
}

_install() {
    _sarch="$(_static_arch)"
    _zarch="$(_zig_arch)"
    [ -z "$_sarch" ] && _die "Unsupported architecture: $(uname -m)"
    [ -z "$_zarch" ] && _die "Unsupported architecture for zig: $(uname -m)"

    _static_base="https://raw.githubusercontent.com/ryanwoodsmall/static-binaries/master/${_sarch}"
    _cache="$SHILL_CORE/cache"

    _log "Installing portable toolchain (zig ${ZIG_VERSION} + make + patchelf)..."

    # --- GNU make (static) ---
    if [ ! -x "$SHILL_CORE/bin/make" ]; then
        _log "Downloading static make..."
        curl -fsSL "${_static_base}/make" -o "$SHILL_CORE/bin/make" || _die "make download failed."
        chmod +x "$SHILL_CORE/bin/make"
    fi
    _ok "make ready."

    # --- static xz (needed to unpack zig) ---
    if [ ! -x "$SHILL_CORE/bin/xz" ]; then
        _log "Downloading static xz..."
        curl -fsSL "${_static_base}/xz" -o "$SHILL_CORE/bin/xz" || _die "xz download failed."
        chmod +x "$SHILL_CORE/bin/xz"
    fi

    # --- patchelf (for portable RPATHs) ---
    if [ ! -x "$SHILL_CORE/bin/patchelf" ]; then
        if curl -fsSL "${_static_base}/patchelf" -o "$SHILL_CORE/bin/patchelf"; then
            chmod +x "$SHILL_CORE/bin/patchelf"
            _ok "patchelf ready."
        else
            _log "Note: Could not fetch patchelf (optional)."
        fi
    fi

    # --- zig (portable C/C++ compiler) ---
    if [ ! -x "$SHILL_CORE/lib/zig/zig" ]; then
        _file="zig-linux-${_zarch}-${ZIG_VERSION}.tar.xz"
        _url="https://ziglang.org/download/${ZIG_VERSION}/${_file}"
        _log "Downloading zig ${ZIG_VERSION} (${_zarch})..."
        curl -fsSL "$_url" -o "$_cache/$_file" || _die "zig download failed."

        _log "Extracting zig..."
        mkdir -p "$SHILL_CORE/lib"
        "$SHILL_CORE/bin/xz" -dc "$_cache/$_file" | tar xf - -C "$SHILL_CORE/lib" || _die "zig extraction failed."
        rm -rf "$SHILL_CORE/lib/zig"
        mv "$SHILL_CORE/lib/zig-linux-${_zarch}-${ZIG_VERSION}" "$SHILL_CORE/lib/zig" || _die "Unexpected zig archive layout."
        rm -f "$_cache/$_file"
    fi

    ln -sf "../lib/zig/zig" "$SHILL_CORE/bin/zig"
    chmod +x "$SHILL_CORE/lib/zig/zig"

    _append_env

    _ok "Toolchain installed (zig + make + patchelf)."
    "$SHILL_CORE/bin/zig" version
}

_remove() {
    _log "Removing toolchain..."
    rm -rf "$SHILL_CORE/lib/zig"
    rm -f "$SHILL_CORE/bin/zig" "$SHILL_CORE/bin/make" "$SHILL_CORE/bin/patchelf"
    if [ -f "$SHILL_CORE/etc/env.sh" ]; then
        sed -i '/# >>> shill:toolchain >>>/,/# <<< shill:toolchain <<</d' "$SHILL_CORE/etc/env.sh" 2>/dev/null || true
    fi
    # Note: static xz is left in bin/ because node.sh may rely on it.
    _ok "Toolchain removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
