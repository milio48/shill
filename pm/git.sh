#!/bin/sh
# ==============================================================================
# Shill PM Installer: git (static, relocatable)
# Static git from supriyo-biswas/static-builds. Built with RUNTIME_PREFIX so it
# runs from any location; no libc/root needed.
# Installed to: $SHILL_CORE/lib/git  (symlinked as $SHILL_CORE/bin/git)
# ==============================================================================

set -e

GIT_VERSION="2.55.0"

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

_install() {
    case "$(uname -m)" in
        x86_64|amd64)   _arch="x86_64" ;;
        aarch64|arm64)  _arch="aarch64" ;;
        *)              _die "Unsupported architecture: $(uname -m) (static git is x86_64/aarch64 only)." ;;
    esac

    _file="git-${GIT_VERSION}-linux-${_arch}.tar.gz"
    _url="https://github.com/supriyo-biswas/static-builds/releases/download/git-${GIT_VERSION}/${_file}"
    _cache="$SHILL_CORE/cache"
    _git_root="$SHILL_CORE/lib/git"

    _log "Installing static git ${GIT_VERSION} (${_arch})..."

    _log "Downloading from GitHub Releases..."
    curl -fsSL "$_url" -o "$_cache/$_file" || _die "Download failed. URL: $_url"

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
