#!/bin/sh
# ==============================================================================
# Shill PM Installer: Go (Golang)
# Official Go toolchain. Pure-Go builds need nothing else; cgo builds use the
# compiler from 'shill install toolchain'.
# Installed to: $SHILL_CORE/lib/go
# Binaries symlinked to: $SHILL_CORE/bin/go, $SHILL_CORE/bin/gofmt
# ==============================================================================

set -e

GO_VERSION="1.24.1"

_log()  { printf '[shill:go] %s\n' "$*"; }
_die()  { printf '[shill:go] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:go] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_append_env() {
    _env_file="$SHILL_CORE/etc/env.sh"
    mkdir -p "$SHILL_CORE/etc"
    [ -f "$_env_file" ] || printf '# Shill environment contract (managed automatically by pm/*.sh)\n' > "$_env_file"
    grep -q '>>> shill:go >>>' "$_env_file" && return 0
    cat <<EOF >> "$_env_file"

# >>> shill:go >>>
export GOROOT="$SHILL_CORE/lib/go"
export GOPATH="$SHILL_CORE/lib/gopath"
export GOCACHE="$SHILL_CORE/cache/go"
export GOMODCACHE="$SHILL_CORE/lib/gopath/pkg/mod"
export GOBIN="$SHILL_CORE/bin"
export GOENV="$SHILL_CORE/etc/go/env"
# <<< shill:go <<<
EOF
}

_install() {
    case "$(uname -m)" in
        x86_64|amd64)        _arch="amd64" ;;
        aarch64|arm64)       _arch="arm64" ;;
        armv7l|armv6l|armhf) _arch="armv6l" ;;
        *)                   _die "Unsupported architecture: $(uname -m)" ;;
    esac

    _file="go${GO_VERSION}.linux-${_arch}.tar.gz"
    _url="https://go.dev/dl/${_file}"
    _cache="$SHILL_CORE/cache"
    _go_root="$SHILL_CORE/lib/go"

    _log "Installing Go ${GO_VERSION} (linux-${_arch})..."

    _log "Downloading from go.dev..."
    curl -fsSL "$_url" -o "$_cache/$_file" || _die "Download failed. URL: $_url"

    _log "Extracting to $SHILL_CORE/lib/go..."
    rm -rf "$_go_root"
    mkdir -p "$_go_root"
    tar -xzf "$_cache/$_file" -C "$_go_root" --strip-components=1 || _die "Extraction failed."
    rm -f "$_cache/$_file"

    ln -sf "../lib/go/bin/go" "$SHILL_CORE/bin/go"
    ln -sf "../lib/go/bin/gofmt" "$SHILL_CORE/bin/gofmt"

    mkdir -p "$SHILL_CORE/lib/gopath" "$SHILL_CORE/cache/go" "$SHILL_CORE/etc/go"
    _append_env

    _ok "Go installed successfully."
    "$SHILL_CORE/bin/go" version
}

_remove() {
    _log "Removing Go..."
    rm -rf "$SHILL_CORE/lib/go"
    rm -f "$SHILL_CORE/bin/go" "$SHILL_CORE/bin/gofmt"
    if [ -f "$SHILL_CORE/etc/env.sh" ]; then
        sed -i '/# >>> shill:go >>>/,/# <<< shill:go <<</d' "$SHILL_CORE/etc/env.sh" 2>/dev/null || true
    fi
    _ok "Go removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
