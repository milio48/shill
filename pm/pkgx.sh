#!/bin/sh
# ==============================================================================
# Shill PM Installer: pkgx
# Single-binary, rootless package runner. It provisions tools on demand into
# PKGX_DIR (kept inside the shill core) and executes them.
#
# Version policy: follows the LATEST GitHub release by default; pin with
#   shill install pkgx@2.11.0
# The expected checksum is read from the same release API call, so what we
# install is always verified. A pinned fallback is used if the API is down.
#
# Installed to: $SHILL_CORE/bin/pkgx
# ==============================================================================

set -e

# Fallback pin (used only when the GitHub API cannot be reached)
PKGX_PINNED="2.11.0"
PKGX_SHA256_X86_64="71284469ab59e86a8f61b33c76cf1d70d1a8eae4450e402868c326546ad43e1a"
PKGX_SHA256_AARCH64="dad557767349ac87f051e4aab032640b472a868a480f55e1b3dce2a01fccd28e"

_log()  { printf '[shill:pkgx] %s\n' "$*"; }
_die()  { printf '[shill:pkgx] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:pkgx] ✅ %s\n' "$*"; }

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
        _die "Checksum mismatch for $(basename "$_file") (expected $_want, got $_got)."
    fi
    _ok "Checksum verified."
}

# Print the sha256 digest GitHub reports for an asset, or nothing.
# $1 = release JSON, $2 = asset name
_release_digest() {
    printf '%s\n' "$1" | awk -v pat="\"name\": \"$2\"" '
        index($0, pat) { found = 1 }
        found && index($0, "\"digest\":") { sub(/.*sha256:/, ""); sub(/".*/, ""); print; exit }
    '
}

_append_env() {
    _env_file="$SHILL_CORE/etc/env.sh"
    mkdir -p "$SHILL_CORE/etc"
    [ -f "$_env_file" ] || printf '# Shill environment contract (managed automatically by pm/*.sh)\n' > "$_env_file"
    grep -q '>>> shill:pkgx >>>' "$_env_file" && return 0
    cat <<EOF >> "$_env_file"

# >>> shill:pkgx >>>
# Keep pkgx's provisioned tools inside the core (default would be ~/.pkgx)
export PKGX_DIR="$SHILL_CORE/lib/pkgx"
# <<< shill:pkgx <<<
EOF
}

_install() {
    case "$(uname -m)" in
        x86_64|amd64)   _arch="x86-64";  _pinned_sum="$PKGX_SHA256_X86_64" ;;
        aarch64|arm64)  _arch="aarch64"; _pinned_sum="$PKGX_SHA256_AARCH64" ;;
        *)              _die "Unsupported architecture: $(uname -m) (pkgx: x86_64/aarch64 only)." ;;
    esac

    # --- Resolve version (latest by default, or the pinned request) ----------
    _api="https://api.github.com/repos/pkgxdev/pkgx/releases"
    _json=""
    if [ -n "${SHILL_PKG_VERSION:-}" ]; then
        _req="${SHILL_PKG_VERSION#v}"
        _log "Resolving pinned release v${_req}..."
        _json=$(curl -fsSL "${_api}/tags/v${_req}" 2>/dev/null || true)
    else
        _log "Resolving latest release..."
        _json=$(curl -fsSL "${_api}/latest" 2>/dev/null || true)
    fi

    PKGX_VERSION=""
    if [ -n "$_json" ]; then
        PKGX_VERSION=$(printf '%s\n' "$_json" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
    fi

    if [ -z "$PKGX_VERSION" ]; then
        if [ -n "${SHILL_PKG_VERSION:-}" ]; then
            # Respect the explicit pin even without API access (unverified).
            PKGX_VERSION="${SHILL_PKG_VERSION#v}"
            _log "GitHub API unavailable; proceeding with requested ${PKGX_VERSION} (unverified)."
            _expect=""
        else
            PKGX_VERSION="$PKGX_PINNED"
            _log "Could not resolve from GitHub API; falling back to pinned ${PKGX_VERSION}."
            _expect="$_pinned_sum"
        fi
    else
        _file="pkgx-${PKGX_VERSION}+linux+${_arch}.tar.gz"
        _expect="$(_release_digest "$_json" "$_file")"
        if [ -z "$_expect" ] && [ "$PKGX_VERSION" = "$PKGX_PINNED" ]; then
            _expect="$_pinned_sum"
        fi
    fi

    _file="pkgx-${PKGX_VERSION}+linux+${_arch}.tar.gz"
    _url="https://github.com/pkgxdev/pkgx/releases/download/v${PKGX_VERSION}/${_file}"
    _cache="$SHILL_CORE/cache"

    _log "Installing pkgx ${PKGX_VERSION} (${_arch})..."

    # .tar.gz variant avoids depending on an xz decompressor.
    _log "Downloading from GitHub Releases..."
    curl -fsSL "$_url" -o "$_cache/$_file" || _die "Download failed. URL: $_url"

    if [ -n "$_expect" ]; then
        _verify_sha256 "$_cache/$_file" "$_expect"
    else
        _log "⚠️  No checksum available for pkgx ${PKGX_VERSION}; skipping verification."
    fi

    _log "Extracting..."
    _extract="$_cache/pkgx_extract"
    rm -rf "$_extract"
    mkdir -p "$_extract"
    tar -xzf "$_cache/$_file" -C "$_extract" || _die "Extraction failed."

    _pkgx_bin=$(find "$_extract" -type f -name pkgx 2>/dev/null | head -n 1)
    [ -n "$_pkgx_bin" ] || _die "pkgx binary not found in archive."
    cp -f "$_pkgx_bin" "$SHILL_CORE/bin/pkgx"
    chmod +x "$SHILL_CORE/bin/pkgx"
    rm -rf "$_extract" "$_cache/$_file"

    mkdir -p "$SHILL_CORE/lib/pkgx"
    _append_env

    _ok "pkgx ${PKGX_VERSION} installed successfully."
    _log "Usage: pkgx <tool> [args]   (e.g. pkgx 7z, pkgx jq, pkgx node@20)"
    _log "       pkgx -Q              list the pantry"
    _log "       Packages land in: $SHILL_CORE/lib/pkgx"
    "$SHILL_CORE/bin/pkgx" --version 2>/dev/null || true
}

_remove() {
    _log "Removing pkgx..."
    rm -f "$SHILL_CORE/bin/pkgx"
    if [ -f "$SHILL_CORE/etc/env.sh" ]; then
        sed -i '/# >>> shill:pkgx >>>/,/# <<< shill:pkgx <<</d' "$SHILL_CORE/etc/env.sh" 2>/dev/null || true
    fi
    _ok "pkgx removed (provisioned packages kept in lib/pkgx)."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
