#!/bin/sh
# ==============================================================================
# Shill PM Installer: git (static, relocatable)
# Built by our own CI in milio48/static-builds (fork of supriyo-biswas).
# RUNTIME_PREFIX build, so it runs from any location; no libc/root needed.
# Installed to: $SHILL_CORE/lib/git  (symlinked as $SHILL_CORE/bin/git)
# ==============================================================================

set -e

GIT_VERSION="2.55.0"

# Custom version: shill install git@2.55.0  (leading 'v' optional)
if [ -n "${SHILL_PKG_VERSION:-}" ]; then
    GIT_VERSION="${SHILL_PKG_VERSION#v}"
fi

# SHA-256 of the release assets, cross-checked against the release's own
# checksums.txt. Pinning the exact bytes means a swapped/tampered artifact is
# rejected at install time.
GIT_SHA256_X86_64="da899acd7ab131239c1f6387597af698966d4d541e329bddcd3c300404bfcde3"
GIT_SHA256_AARCH64="a8ed632587ef6f2bc6be27dc0a3b01f9635af4e4f91e785fb5dcba902814e143"

_log()  { printf '[shill:git] %s\n' "$*"; }
_die()  { printf '[shill:git] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:git] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_append_env() {
    _env_file="$SHILL_CORE/etc/env.sh"
    mkdir -p "$SHILL_CORE/etc"
    [ -f "$_env_file" ] || printf '# Shill environment contract (managed automatically by pm/*.sh)\n' > "$_env_file"
    grep -q '>>> shill:git >>>' "$_env_file" && return 0
    cat <<EOF >> "$_env_file"

# >>> shill:git >>>
# Keep git's config, CA bundle and helper path inside the core.
export GIT_EXEC_PATH="$SHILL_CORE/lib/git/libexec/git-core"
export GIT_SSL_CAINFO="$SHILL_CORE/etc/cacert.pem"
export GIT_CONFIG_GLOBAL="$SHILL_CORE/etc/gitconfig"
# <<< shill:git <<<
EOF
}

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

_install() {
    case "$(uname -m)" in
        x86_64|amd64)   _arch="x86_64";  _sha256="$GIT_SHA256_X86_64" ;;
        aarch64|arm64)  _arch="aarch64"; _sha256="$GIT_SHA256_AARCH64" ;;
        *)              _die "Unsupported architecture: $(uname -m) (static git is x86_64/aarch64 only)." ;;
    esac

    _file="git-${GIT_VERSION}-linux-${_arch}.tar.gz"
    _url="https://github.com/milio48/static-builds/releases/download/git-${GIT_VERSION}/${_file}"
    _cache="$SHILL_CORE/cache"
    _git_root="$SHILL_CORE/lib/git"

    _log "Installing static git ${GIT_VERSION} (${_arch})..."

    _log "Downloading from GitHub Releases..."
    curl -fsSL "$_url" -o "$_cache/$_file" || _die "Download failed. URL: $_url"

    # Integrity: use the pinned hash for the default version; for any other
    # version, fall back to the release's own checksums.txt.
    if [ "$GIT_VERSION" = "2.55.0" ]; then
        _verify_sha256 "$_cache/$_file" "$_sha256"
    else
        _sums=$(curl -fsSL "https://github.com/milio48/static-builds/releases/download/git-${GIT_VERSION}/checksums.txt" 2>/dev/null || true)
        _want=$(printf '%s\n' "$_sums" | awk -v n="$(basename "$_file")" '$2 == n { print $1 }')
        if [ -n "$_want" ]; then
            _verify_sha256 "$_cache/$_file" "$_want"
        else
            _log "⚠️  No checksum published for git ${GIT_VERSION}; skipping verification."
        fi
    fi

    _log "Extracting to $SHILL_CORE/lib/git..."
    rm -rf "$_git_root"
    mkdir -p "$_git_root"
    tar -xzf "$_cache/$_file" -C "$_git_root" || _die "Extraction failed."
    rm -f "$_cache/$_file"

    [ -x "$_git_root/bin/git" ] || _die "git binary not found in archive."

    ln -sf "../lib/git/bin/git" "$SHILL_CORE/bin/git"
    _append_env

    _ok "git installed successfully."
    "$SHILL_CORE/bin/git" --version
}

_remove() {
    _log "Removing git..."
    rm -rf "$SHILL_CORE/lib/git"
    rm -f "$SHILL_CORE/bin/git"
    if [ -f "$SHILL_CORE/etc/env.sh" ]; then
        sed -i '/# >>> shill:git >>>/,/# <<< shill:git <<</d' "$SHILL_CORE/etc/env.sh" 2>/dev/null || true
    fi
    _ok "git removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
