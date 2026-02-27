#!/bin/sh
# ==============================================================================
# SHILL - Portable Standarized Userspace ("The Stowaway")
# Zero-Dependency, Self-Modifying, Procedural Manager
# https://github.com/milio48/shill
# ==============================================================================

# --- CONFIG AREA (DO NOT EDIT MANUALLY) ---
SHILL_CORE=''
# ------------------------------------------

SHILL_REPO="https://raw.githubusercontent.com/milio48/shill/main"

# ==============================================
# 1. CORE HELPERS
# ==============================================

_log()   { printf '[shill] %s\n' "$*"; }
_warn()  { printf '[shill] ⚠️  %s\n' "$*" >&2; }
_die()   { printf '[shill] ❌ %s\n' "$*" >&2; exit 1; }
_ok()    { printf '[shill] ✅ %s\n' "$*"; }

_get_arch() {
    case "$(uname -m)" in
        x86_64|amd64)           echo "x86_64"  ;;
        aarch64|arm64)          echo "aarch64"  ;;
        armv7l|armv6l|armhf)    echo "armhf"    ;;
        *)  _die "Unsupported architecture: $(uname -m)" ;;
    esac
}

# ==============================================
# 2. 10-LAYER BRUTE-FORCE DOWNLOADER
# ==============================================
# Rantai survival: tries every possible tool on the host
# to download a file. Guarantees at least one method works.

_download() {
    _dl_url="$1"
    _dl_out="$2"

    _log "Downloading: $(basename "$_dl_url")"

    # --- Layer 1: curl ---
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$_dl_url" -o "$_dl_out" 2>/dev/null && return 0
    fi

    # --- Layer 2: wget ---
    if command -v wget >/dev/null 2>&1; then
        wget -q "$_dl_url" -O "$_dl_out" 2>/dev/null && return 0
    fi

    # --- Layer 3: python3 / python ---
    for _py in python3 python; do
        if command -v "$_py" >/dev/null 2>&1; then
            "$_py" -c "
import sys
try:
    from urllib.request import urlretrieve
except ImportError:
    from urllib import urlretrieve
urlretrieve('$_dl_url', '$_dl_out')
" 2>/dev/null && return 0
        fi
    done

    # --- Layer 4: perl ---
    if command -v perl >/dev/null 2>&1; then
        perl -e "
use strict; use warnings;
eval { require HTTP::Tiny };
if (!\$@) {
    my \$r = HTTP::Tiny->new->get('$_dl_url');
    if (\$r->{success}) { open my \$f,'>','$_dl_out'; binmode \$f; print \$f \$r->{content}; close \$f; exit 0; }
}
eval { require LWP::Simple };
if (!\$@) { LWP::Simple::getstore('$_dl_url','$_dl_out') == 200 && exit 0; }
exit 1;
" 2>/dev/null && return 0
    fi

    # --- Layer 5: php ---
    if command -v php >/dev/null 2>&1; then
        php -r "
\$d = @file_get_contents('$_dl_url');
if (\$d !== false) { file_put_contents('$_dl_out', \$d); exit(0); }
if (@copy('$_dl_url', '$_dl_out')) { exit(0); }
exit(1);
" 2>/dev/null && return 0
    fi

    # --- Layer 6: ruby ---
    if command -v ruby >/dev/null 2>&1; then
        ruby -e "
require 'open-uri'
File.open('$_dl_out', 'wb') { |f| f.write(URI.open('$_dl_url').read) }
" 2>/dev/null && return 0
    fi

    # --- Layer 7: node / nodejs ---
    for _nd in node nodejs; do
        if command -v "$_nd" >/dev/null 2>&1; then
            "$_nd" -e "
const https = require('https'), http = require('http'), fs = require('fs'), url = require('url');
const u = new url.URL('$_dl_url');
const mod = u.protocol === 'https:' ? https : http;
function dl(target, depth) {
    if (depth > 5) { process.exit(1); }
    mod.get(target, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
            dl(res.headers.location, depth + 1); return;
        }
        if (res.statusCode !== 200) { process.exit(1); }
        const f = fs.createWriteStream('$_dl_out');
        res.pipe(f); f.on('finish', () => f.close());
    }).on('error', () => process.exit(1));
}
dl('$_dl_url', 0);
" 2>/dev/null && return 0
        fi
    done

    # --- Layer 8: openssl s_client ---
    if command -v openssl >/dev/null 2>&1; then
        _dl_host=$(echo "$_dl_url" | sed -e 's|https\?://||' -e 's|/.*||')
        _dl_path=$(echo "$_dl_url" | sed -e 's|https\?://[^/]*||')
        {
            printf "GET %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n" "$_dl_path" "$_dl_host"
            sleep 3
        } | openssl s_client -connect "${_dl_host}:443" -quiet 2>/dev/null | \
            sed '1,/^\r$/d' > "$_dl_out" 2>/dev/null
        [ -s "$_dl_out" ] && return 0
    fi

    # --- Layer 9: socat ---
    if command -v socat >/dev/null 2>&1; then
        _dl_host=$(echo "$_dl_url" | sed -e 's|https\?://||' -e 's|/.*||')
        _dl_path=$(echo "$_dl_url" | sed -e 's|https\?://[^/]*||')
        printf "GET %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n" "$_dl_path" "$_dl_host" | \
            socat - OPENSSL:"${_dl_host}:443",verify=0 2>/dev/null | \
            sed '1,/^\r$/d' > "$_dl_out" 2>/dev/null
        [ -s "$_dl_out" ] && return 0
    fi

    # --- Layer 10: bash /dev/tcp (HTTP only, last resort) ---
    if [ -e /dev/tcp ] 2>/dev/null || bash -c 'echo >/dev/tcp/localhost/80' 2>/dev/null; then
        _dl_host=$(echo "$_dl_url" | sed -e 's|https\?://||' -e 's|/.*||')
        _dl_path=$(echo "$_dl_url" | sed -e 's|https\?://[^/]*||')
        bash -c "
exec 3<>/dev/tcp/${_dl_host}/80
printf 'GET %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n' '$_dl_path' '$_dl_host' >&3
sed '1,/^\r$/d' <&3 > '$_dl_out'
exec 3>&-
" 2>/dev/null
        [ -s "$_dl_out" ] && return 0
    fi

    _warn "All 10 download layers failed for: $_dl_url"
    return 1
}

# ==============================================
# 3. SETUP & SELF-MODIFICATION
# ==============================================

_setup() {
    _log "🏴‍☠️ Shill Initial Setup"
    echo ""
    echo "  Select Core Directory:"
    echo "    1) ~/.shill          (Permanent, recommended)"
    echo "    2) /tmp/.shill       (Volatile, wiped on reboot)"
    echo "    3) $(pwd)/.shill     (Current directory)"
    echo "    4) Custom path"
    echo ""
    printf "  Choice [1-4]: "
    read -r _choice

    _target_dir=""
    case "$_choice" in
        1) _target_dir="$HOME/.shill" ;;
        2) _target_dir="/tmp/.shill" ;;
        3) _target_dir="$(pwd)/.shill" ;;
        4)
            printf "  Enter absolute path: "
            read -r _target_dir
            ;;
        *) _die "Invalid choice." ;;
    esac

    # Resolve to absolute path
    case "$_target_dir" in
        /*) ;; # already absolute
        ~/*) _target_dir="$HOME/${_target_dir#\~/}" ;;
        *)  _target_dir="$(cd "$(dirname "$_target_dir")" 2>/dev/null && pwd)/$(basename "$_target_dir")" ;;
    esac

    # Self-Modification: rewrite SHILL_CORE inside this script
    _script_path="$(readlink -f "$0" 2>/dev/null || echo "$(cd "$(dirname "$0")" && pwd)/$(basename "$0")")"

    _log "Locking SHILL_CORE to: $_target_dir"
    sed "s|^SHILL_CORE=''.*|SHILL_CORE='$_target_dir'|" "$_script_path" > "${_script_path}.tmp" && \
    mv "${_script_path}.tmp" "$_script_path" && \
    chmod +x "$_script_path"

    if [ $? -ne 0 ]; then
        _die "Failed to self-modify script."
    fi

    # Run bootstrap with the new value (pass script path for shill wrapper)
    SHILL_CORE="$_target_dir" _bootstrap "$_script_path"
}

# ==============================================
# 4. BOOTSTRAP (THE ASSEMBLY)
# ==============================================

_bootstrap() {
    _log "Bootstrapping environment in: $SHILL_CORE"

    # Resolve shill.sh path (passed from _setup, or detect from $0)
    _shill_script="${1:-$(readlink -f "$0" 2>/dev/null || echo "$(cd "$(dirname "$0")" && pwd)/$(basename "$0")")}"

    mkdir -p "$SHILL_CORE/bin" "$SHILL_CORE/busybox_links" "$SHILL_CORE/cache"

    _arch="$(_get_arch)"
    _static_base="https://raw.githubusercontent.com/ryanwoodsmall/static-binaries/master/${_arch}"

    # --- Phase 1: Secure static curl binary ---
    if [ ! -x "$SHILL_CORE/bin/curl.bin" ]; then
        _log "Phase 1/5: Downloading static curl..."
        _download "${_static_base}/curl" "$SHILL_CORE/bin/curl.bin" || _die "Cannot download static curl. Bootstrap failed."
        chmod +x "$SHILL_CORE/bin/curl.bin"
        _ok "Static curl binary secured."
    else
        _ok "Static curl binary already present."
    fi

    # --- Phase 1.5: Secure CA certificate bundle ---
    # Static curl from ryanwoodsmall is built with mbedTLS and has TWO hardcoded
    # paths: /usr/local/crosware/etc/ssl/cert.pem (file) and .../certs (dir).
    # CURL_CA_BUNDLE env only fixes the file path; the dir path still fails.
    # Solution: fetch cacert.pem with -k (one-time insecure), then create a
    # wrapper script that always passes --cacert (overrides BOTH paths).
    mkdir -p "$SHILL_CORE/etc"
    if [ ! -f "$SHILL_CORE/etc/cacert.pem" ]; then
        _log "Phase 1.5/5: Fetching CA certificate bundle..."
        "$SHILL_CORE/bin/curl.bin" -k -sSfL "https://curl.se/ca/cacert.pem" -o "$SHILL_CORE/etc/cacert.pem" || \
            _die "Cannot download CA bundle. Bootstrap failed."
        _ok "CA certificate bundle secured."
    else
        _ok "CA certificate bundle already present."
    fi

    # --- Create curl wrapper (always uses our cacert.pem + capath) ---
    # mbedTLS has TWO hardcoded lookups: --cacert (file) AND --capath (directory).
    # We must override BOTH or it will still fail on the directory lookup.
    mkdir -p "$SHILL_CORE/etc/certs"
    cat <<CURLWRAP > "$SHILL_CORE/bin/curl"
#!/bin/sh
exec "$SHILL_CORE/bin/curl.bin" --cacert "$SHILL_CORE/etc/cacert.pem" --capath "$SHILL_CORE/etc/certs" "\$@"
CURLWRAP
    chmod +x "$SHILL_CORE/bin/curl"
    _ok "Curl wrapper created (auto --cacert + --capath)."

    # From here on, use our wrapper
    _CURL="$SHILL_CORE/bin/curl"

    # --- Phase 2: Download static bash ---
    if [ ! -x "$SHILL_CORE/bin/bash" ]; then
        _log "Phase 2/5: Downloading static bash..."
        "$_CURL" -fsSL "${_static_base}/bash" -o "$SHILL_CORE/bin/bash" || _die "Cannot download static bash."
        chmod +x "$SHILL_CORE/bin/bash"
        _ok "Static bash secured."
    else
        _ok "Static bash already present."
    fi

    # --- Phase 3: Download static busybox ---
    if [ ! -x "$SHILL_CORE/bin/busybox" ]; then
        _log "Phase 3/5: Downloading static busybox..."
        "$_CURL" -fsSL "${_static_base}/busybox" -o "$SHILL_CORE/bin/busybox" || _die "Cannot download static busybox."
        chmod +x "$SHILL_CORE/bin/busybox"
        _ok "Static busybox secured."
    else
        _ok "Static busybox already present."
    fi

    # --- Phase 4: Build symlink farm ---
    _log "Phase 4/5: Building busybox symlink farm..."
    _build_symlink_farm

    # --- Phase 5: Create shell config & shill wrapper ---
    _log "Phase 5/5: Generating shell config..."
    _create_rc

    # Create 'shill' command wrapper so it's available inside the shell
    cat <<SHILLWRAP > "$SHILL_CORE/bin/shill"
#!/bin/sh
exec "$_shill_script" "\$@"
SHILLWRAP
    chmod +x "$SHILL_CORE/bin/shill"
    _ok "'shill' command wrapper created."

    _ok "Bootstrap complete! Run './shill.sh enter' to start."
}

_build_symlink_farm() {
    _bb="$SHILL_CORE/bin/busybox"
    _farm="$SHILL_CORE/busybox_links"

    # Clean old symlinks
    rm -f "$_farm"/* 2>/dev/null

    # Get list of applets from busybox itself
    _applets=$("$_bb" --list 2>/dev/null)

    if [ -z "$_applets" ]; then
        _warn "Could not list busybox applets. Trying fallback..."
        _applets=$("$_bb" 2>&1 | sed -n '/Currently defined functions:/,$ p' | tail -n +2 | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed '/^$/d')
    fi

    _count=0
    for _applet in $_applets; do
        # Skip applets that conflict with our bin/ (our binaries have priority)
        case "$_applet" in
            bash|curl|curl.bin|busybox|shill|sh) continue ;;
        esac
        if [ ! -e "$_farm/$_applet" ]; then
            ln -sf "$_bb" "$_farm/$_applet"
            _count=$((_count + 1))
        fi
    done

    _ok "Symlink farm created: $_count applets linked."
}

_create_rc() {
    _rc_file="$SHILL_CORE/.shill_rc"
    cat <<'RCEOF' > "$_rc_file"
# ==============================================
# .shill_rc - Shill Interactive Shell Config
# ==============================================
RCEOF

    # These need variable expansion, so we use a regular heredoc
    cat <<RCEOF >> "$_rc_file"
export SHILL_CORE="$SHILL_CORE"
export PATH="$SHILL_CORE/bin:$SHILL_CORE/busybox_links:\$PATH"
export HISTFILE="$SHILL_CORE/.shill_history"
export HISTSIZE=5000
export HISTFILESIZE=10000
RCEOF

    # PS1 and aliases (no expansion needed)
    cat <<'RCEOF' >> "$_rc_file"

# Prompt
export PS1='\n\[\e[1;35m\]⚓ shill\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]\$ '

# Emacs keybindings (arrow keys, ctrl+a/e, etc.)
set -o emacs

# Useful aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# Greeting
echo ""
echo "  🏴‍☠️  Shill Userspace Active"
echo "  📂  Core: $SHILL_CORE"
echo "  🔧  Type 'exit' to leave"
echo ""
RCEOF
}

# ==============================================
# 5. RUNTIME COMMANDS
# ==============================================

_enter() {
    [ ! -d "$SHILL_CORE" ] && _die "SHILL_CORE directory not found. Run './shill.sh setup' first."
    [ ! -x "$SHILL_CORE/bin/bash" ] && _die "Static bash not found. Run './shill.sh setup' first."

    _log "Entering Shill Userspace..."

    # Regenerate RC in case paths changed
    _create_rc

    # Replace current process with our static bash
    PATH="$SHILL_CORE/bin:$SHILL_CORE/busybox_links:$PATH" \
    exec "$SHILL_CORE/bin/bash" --rcfile "$SHILL_CORE/.shill_rc"
}

_space() {
    [ ! -d "$SHILL_CORE" ] && _die "SHILL_CORE directory not found. Run './shill.sh setup' first."

    if [ $# -eq 0 ]; then
        _die "Usage: shill.sh space <command> [args...]"
    fi

    PATH="$SHILL_CORE/bin:$SHILL_CORE/busybox_links:$PATH" "$@"
}

_list() {
    echo ""
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║        📦 Shill Package List         ║"
    echo "  ╚══════════════════════════════════════╝"
    echo ""

    # --- Local packages ---
    echo "  ── Installed (local) ──────────────────"
    if [ -d "$SHILL_CORE/bin" ]; then
        for _bin in "$SHILL_CORE/bin"/*; do
            [ -f "$_bin" ] && [ -x "$_bin" ] && echo "    ✅ $(basename "$_bin")"
        done
    else
        echo "    (none)"
    fi

    echo ""

    # --- Remote catalog ---
    echo "  ── Available (remote) ────────────────"
    _catalog_url="${SHILL_REPO}/pm/pm-ls.txt"

    if [ -x "$SHILL_CORE/bin/curl" ]; then
        _catalog=$("$SHILL_CORE/bin/curl" -fsSL "$_catalog_url" 2>/dev/null)
    else
        _catalog=$(_tmp_file=$(mktemp 2>/dev/null || echo "/tmp/.shill_cat_$$")
        _download "$_catalog_url" "$_tmp_file" 2>/dev/null && cat "$_tmp_file" && rm -f "$_tmp_file")
    fi

    if [ -n "$_catalog" ]; then
        echo "$_catalog" | while IFS=: read -r _name _desc; do
            # Check if already installed
            if [ -x "$SHILL_CORE/bin/$_name" ]; then
                echo "    ✅ $_name  — $_desc"
            else
                echo "    📥 $_name  — $_desc"
            fi
        done
    else
        _warn "Could not fetch remote catalog."
    fi

    echo ""
}

_install() {
    _pkg="$1"
    [ -z "$_pkg" ] && _die "Usage: shill.sh install <package>"

    _log "Installing: $_pkg"

    _installer_url="${SHILL_REPO}/pm/${_pkg}.sh"
    _installer_path="$SHILL_CORE/cache/${_pkg}.sh"

    # Download installer script
    if [ -x "$SHILL_CORE/bin/curl" ]; then
        "$SHILL_CORE/bin/curl" -fsSL "$_installer_url" -o "$_installer_path" 2>/dev/null
    else
        _download "$_installer_url" "$_installer_path"
    fi

    if [ ! -s "$_installer_path" ]; then
        _die "Package '$_pkg' not found in registry."
    fi

    chmod +x "$_installer_path"

    # Execute installer within Shill environment
    SHILL_CORE="$SHILL_CORE" \
    PATH="$SHILL_CORE/bin:$SHILL_CORE/busybox_links:$PATH" \
    sh "$_installer_path"

    _result=$?

    # Cleanup
    rm -f "$_installer_path" 2>/dev/null

    if [ $_result -eq 0 ]; then
        _ok "Package '$_pkg' installed successfully."
    else
        _die "Installation of '$_pkg' failed."
    fi
}

_remove() {
    _pkg="$1"
    [ -z "$_pkg" ] && _die "Usage: shill.sh remove <package>"

    # Protect core binaries
    case "$_pkg" in
        curl|curl.bin|bash|busybox|cacert.pem|shill)
            _die "Cannot remove core component '$_pkg'. Use 'destroy' to wipe everything."
            ;;
    esac

    _log "Removing: $_pkg"

    _installer_url="${SHILL_REPO}/pm/${_pkg}.sh"
    _installer_path="$SHILL_CORE/cache/${_pkg}_remove.sh"

    # Download installer script
    if [ -x "$SHILL_CORE/bin/curl" ]; then
        "$SHILL_CORE/bin/curl" -fsSL "$_installer_url" -o "$_installer_path" 2>/dev/null
    else
        _download "$_installer_url" "$_installer_path"
    fi

    if [ ! -s "$_installer_path" ]; then
        # Fallback: if script not found, just try to delete the binary from bin/
        if [ -f "$SHILL_CORE/bin/$_pkg" ]; then
            rm -f "$SHILL_CORE/bin/$_pkg"
            _ok "Removed $_pkg (binary only, script not found)."
            return 0
        else
            _die "Package '$_pkg' not found in registry and not in bin/."
        fi
    fi

    chmod +x "$_installer_path"

    # Execute installer with 'remove' argument
    SHILL_CORE="$SHILL_CORE" \
    PATH="$SHILL_CORE/bin:$SHILL_CORE/busybox_links:$PATH" \
    sh "$_installer_path" remove

    _result=$?

    # Cleanup script
    rm -f "$_installer_path" 2>/dev/null

    if [ $_result -eq 0 ]; then
        _ok "Package '$_pkg' removed successfully."
    else
        _die "Removal of '$_pkg' failed."
    fi
}

_destroy() {
    if [ -z "$SHILL_CORE" ]; then
        _warn "SHILL_CORE is already empty. Nothing to destroy."
        return 0
    fi

    echo ""
    printf "  💣 This will permanently delete: %s\n" "$SHILL_CORE"
    printf "  Are you sure? [y/N]: "
    read -r _confirm
    case "$_confirm" in
        y|Y|yes|YES)
            rm -rf "$SHILL_CORE"

            # Reset SHILL_CORE in the script file
            _script_path="$(readlink -f "$0" 2>/dev/null || echo "$(cd "$(dirname "$0")" && pwd)/$(basename "$0")")"
            sed "s|^SHILL_CORE=.*|SHILL_CORE=''|" "$_script_path" > "${_script_path}.tmp" && \
            mv "${_script_path}.tmp" "$_script_path" && \
            chmod +x "$_script_path"

            _ok "Shill wiped out. Data core deleted."
            
            # Self-destruct the script itself
            _log "Self-destructing script file: $_script_path"
            rm -f "$_script_path"
            echo "✅ Goodbye."
            exit 0
            ;;
        *)
            _log "Destroy cancelled."
            ;;
    esac
}

_version() {
    echo "shill v1.0.0 — Portable Standarized Userspace"
    echo "https://github.com/milio48/shill"
}

_help() {
    echo ""
    echo "  🏴‍☠️  SHILL — Portable Standarized Userspace"
    echo ""
    echo "  Usage: ./shill.sh <command> [args]"
    echo ""
    echo "  Commands:"
    echo "    setup           Run initial setup (choose directory, download binaries)"
    echo "    enter           Launch interactive Shill shell (with arrow keys & history)"
    echo "    space <cmd>     Run a single command in Shill environment"
    echo "    ls              List installed & available packages"
    echo "    install <pkg>   Install a package from the registry"
    echo "    remove <pkg>    Remove an installed package"
    echo "    destroy         Wipe Shill completely (with confirmation)"
    echo "    version         Show version info"
    echo "    help            Show this help message"
    echo ""
}

# ==============================================
# 6. GATEKEEPER & MAIN ROUTER
# ==============================================

# If SHILL_CORE is empty and command is not setup/help/version/destroy, force setup
if [ -z "$SHILL_CORE" ]; then
    case "$1" in
        help)    _help; exit 0 ;;
        version) _version; exit 0 ;;
        destroy) _log "Nothing to destroy (SHILL_CORE is empty)."; exit 0 ;;
        *)
            _warn "SHILL_CORE is not set. Starting initial setup..."
            echo ""
            _setup
            exit 0
            ;;
    esac
fi

# Main router
case "$1" in
    setup)   _setup ;;
    enter)   _enter ;;
    space)   shift; _space "$@" ;;
    ls)      _list ;;
    install) _install "$2" ;;
    remove)  _remove "$2" ;;
    destroy) _destroy ;;
    version) _version ;;
    help|--help|-h|"")
        _help ;;
    *)
        _warn "Unknown command: $1"
        _help
        exit 1
        ;;
esac
