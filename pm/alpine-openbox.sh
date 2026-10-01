#!/bin/sh
# ==============================================================================
# Shill PM Installer: alpine-openbox
# Lightweight Openbox desktop inside proot-alpine, served via VNC + noVNC (browser).
# Requires: proot-alpine (shill install proot-alpine)
#
# VNC password (non-interactive), default 123456. shill.sh does not forward
# extra CLI args to pm scripts, so the password is passed via environment:
#   VNC_PASSWORD=secret shill install alpine-openbox
# Change later (plain argument):  alpine-openbox passwd <new-password>
# ==============================================================================

set -e

_log()  { printf '[shill:alpine-openbox] %s\n' "$*"; }
_die()  { printf '[shill:alpine-openbox] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:alpine-openbox] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_PKGS="tigervnc novnc websockify openbox tint2 xterm xrdb xsetroot font-dejavu"
_VIRT=".shill-openbox"

_install() {
    _pa="$SHILL_CORE/bin/proot-alpine"
    _root="$SHILL_CORE/lib/proot-alpine"
    _wrapper="$SHILL_CORE/bin/alpine-openbox"
    _logfile="$SHILL_CORE/cache/alpine-openbox.log"

    # --- Prerequisite ---
    if [ ! -x "$_pa" ] || [ ! -d "$_root" ]; then
        _die "proot-alpine is not installed. Run: shill install proot-alpine"
    fi

    # --- Password: env VNC_PASSWORD > default (never interactive) ---
    _pw="${VNC_PASSWORD:-123456}"
    [ "${#_pw}" -ge 6 ] || _die "VNC password must be at least 6 characters."
    [ "${#_pw}" -le 8 ] || _log "⚠️ VNC only uses the first 8 characters of the password."

    _log "Installing Openbox desktop stack inside proot-alpine..."
    mkdir -p "$SHILL_CORE/cache"

    # Ensure community repository is enabled in guest
    if [ -f "$_root/etc/apk/repositories" ]; then
        sed -i 's/^#\(.*\/community\)/\1/' "$_root/etc/apk/repositories" 2>/dev/null || true
    fi

    # 1. Packages (grouped as an apk virtual package => fully removable)
    # shellcheck disable=SC2086
    "$_pa" add --no-cache --virtual "$_VIRT" $_PKGS \
        || _die "Package installation failed."

    # 2. Guest-side runner (runs inside Alpine)
    _log "Writing guest runner..."
    mkdir -p "$_root/usr/local/bin" "$_root/root/.vnc"
    cat <<'GUEST' > "$_root/usr/local/bin/shill-openbox"
#!/bin/sh
# shill-openbox: guest-side runner (Xvnc + Openbox + noVNC)
DISPLAY_NUM="${DISPLAY_NUM:-1}"
GEOMETRY="${GEOMETRY:-1280x720}"
WEB_PORT="${WEB_PORT:-6080}"
VNC_PORT=$((5900 + DISPLAY_NUM))
PASSFILE="/root/.vnc/passwd"
RUN="/tmp/shill-openbox"

die() { echo "[shill-openbox] ERROR: $*" >&2; exit 1; }

_alive() { [ -f "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null; }

do_passwd() {
    pw="$1"
    [ "${#pw}" -ge 6 ] || die "Password must be at least 6 characters."
    mkdir -p /root/.vnc
    rm -f "$PASSFILE.tmp"
    printf '%s\n' "$pw" | vncpasswd -f > "$PASSFILE.tmp" 2>/dev/null || true
    if [ ! -s "$PASSFILE.tmp" ]; then
        # fallback for vncpasswd variants without -f
        printf '%s\n%s\nn\n' "$pw" "$pw" | vncpasswd "$PASSFILE.tmp" >/dev/null 2>&1 || true
    fi
    [ -s "$PASSFILE.tmp" ] || die "Failed to write VNC password file."
    mv -f "$PASSFILE.tmp" "$PASSFILE"
    chmod 600 "$PASSFILE"
}

do_start() {
    [ -s "$PASSFILE" ] || die "No VNC password set."
    mkdir -p "$RUN"
    if _alive "$RUN/xvnc.pid" && _alive "$RUN/web.pid"; then
        echo "READY port=$WEB_PORT (already running)"; exit 0
    fi
    do_stop

    export HOME=/root
    export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
    mkdir -p "$XDG_RUNTIME_DIR" /tmp/.X11-unix
    chmod 700 "$XDG_RUNTIME_DIR"
    rm -f "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}"

    Xvnc ":$DISPLAY_NUM" -geometry "$GEOMETRY" -depth 24 \
        -rfbport "$VNC_PORT" -rfbauth "$PASSFILE" \
        -SecurityTypes VncAuth -localhost >"$RUN/xvnc.log" 2>&1 &
    echo $! > "$RUN/xvnc.pid"
    sleep 2
    _alive "$RUN/xvnc.pid" || { cat "$RUN/xvnc.log" >&2; die "Xvnc failed to start."; }

    DISPLAY=":$DISPLAY_NUM" /root/.vnc/xstartup >"$RUN/session.log" 2>&1 &
    echo $! > "$RUN/session.pid"

    websockify --web=/usr/share/novnc "$WEB_PORT" "127.0.0.1:$VNC_PORT" \
        >"$RUN/web.log" 2>&1 &
    echo $! > "$RUN/web.pid"
    sleep 1
    _alive "$RUN/web.pid" || { cat "$RUN/web.log" >&2; die "websockify failed to start."; }

    echo "READY port=$WEB_PORT"
    trap 'do_stop; exit 0' INT TERM
    wait
}

do_stop() {
    for f in web session xvnc; do
        if _alive "$RUN/$f.pid"; then kill "$(cat "$RUN/$f.pid")" 2>/dev/null || true; fi
        rm -f "$RUN/$f.pid"
    done
    rm -f "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}"
}

case "${1:-}" in
    start)  do_start ;;
    stop)   do_stop ;;
    status) _alive "$RUN/xvnc.pid" && _alive "$RUN/web.pid" ;;
    passwd) do_passwd "${2:-}" ;;
    *) echo "usage: shill-openbox {start|stop|status|passwd <pw>}"; exit 1 ;;
esac
GUEST
    chmod +x "$_root/usr/local/bin/shill-openbox"

    # 3. Session config (xstartup, fonts, terminal alias)
    _log "Writing desktop session config..."
    cat <<'XSTART' > "$_root/root/.vnc/xstartup"
#!/bin/sh
export HOME=/root
command -v xrdb >/dev/null 2>&1 && [ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
xsetroot -solid "#2e3440" &
tint2 &
xterm &
exec openbox
XSTART
    chmod +x "$_root/root/.vnc/xstartup"

    cat <<'XRES' > "$_root/root/.Xresources"
XTerm*faceName: DejaVu Sans Mono
XTerm*faceSize: 11
XRES
    # Openbox's default menu calls x-terminal-emulator, which Alpine lacks
    ln -sf /usr/bin/xterm "$_root/usr/local/bin/x-terminal-emulator"

    # Ensure root access to noVNC web interface via index.html
    if [ -f "$_root/usr/share/novnc/vnc.html" ] && [ ! -f "$_root/usr/share/novnc/index.html" ]; then
        ln -sf vnc.html "$_root/usr/share/novnc/index.html"
    fi

    # 4. VNC password (non-interactive)
    "$_pa" /usr/local/bin/shill-openbox passwd "$_pw" \
        || _die "Failed to set VNC password."

    # 5. Host-side command wrapper
    _log "Creating 'alpine-openbox' command wrapper..."
    cat <<'WRAP' > "$_wrapper"
#!/bin/sh
# alpine-openbox -> manage the Openbox desktop (VNC + noVNC) in proot-alpine
#   alpine-openbox start | stop | status | guide | logs | passwd <new-password>
# Env (for start): GEOMETRY=1280x720  WEB_PORT=6080  DISPLAY_NUM=1
_PA="__PA__"
_LOG="__LOG__"
_G="/usr/local/bin/shill-openbox"
_PORT="${WEB_PORT:-6080}"

_guide() {
cat <<EOF

  🖥️  Openbox desktop is running on port ${_PORT} (local only).

  Expose it with a tunnel, run ONE of these in the Shill shell:

    [cloudflared]  (no account needed)
      cloudflared tunnel --url http://localhost:${_PORT}
      - get the binary: 'shill ls' (if packaged), or
        https://github.com/cloudflare/cloudflared/releases
        (cloudflared-linux-amd64 / cloudflared-linux-arm64)

    [ngrok]  (free account + authtoken required)
      ngrok config add-authtoken <YOUR_TOKEN>
      ngrok http ${_PORT}

  Then open the https URL the tunnel prints, with this path appended:

      <TUNNEL_URL>/vnc.html?autoconnect=1&resize=scale

  Local test:  http://localhost:${_PORT}/vnc.html?autoconnect=1&resize=scale
  Password:    your VNC password (default 123456, max 8 chars used)

  ⚠️  The tunnel URL is PUBLIC; the VNC password is the only protection.
      Change it:  alpine-openbox passwd <new-password>
      Stop it:    alpine-openbox stop   (and close the tunnel)

EOF
}

case "${1:-}" in
    start)
        if "$_PA" "$_G" status >/dev/null 2>&1; then
            echo "Already running."; _guide; exit 0
        fi
        mkdir -p "$(dirname "$_LOG")"
        : > "$_LOG"
        env WEB_PORT="$_PORT" GEOMETRY="${GEOMETRY:-1280x720}" DISPLAY_NUM="${DISPLAY_NUM:-1}" \
            nohup "$_PA" "$_G" start >"$_LOG" 2>&1 &
        _pid=$!
        _i=0
        while [ "$_i" -lt 45 ]; do
            grep -q '^READY' "$_LOG" 2>/dev/null && break
            kill -0 "$_pid" 2>/dev/null || break
            _i=$((_i + 1)); sleep 1
        done
        if grep -q '^READY' "$_LOG" 2>/dev/null; then
            _guide
        else
            echo "❌ Failed to start. Log:" >&2; cat "$_LOG" >&2; exit 1
        fi
        ;;
    stop)    "$_PA" "$_G" stop && echo "Stopped." ;;
    status)  if "$_PA" "$_G" status >/dev/null 2>&1; then echo "running"; else echo "stopped"; exit 1; fi ;;
    guide)   _guide ;;
    logs)    cat "$_LOG" 2>/dev/null; cat /tmp/shill-openbox/*.log 2>/dev/null ;;
    passwd)
        [ -n "${2:-}" ] || { echo "usage: alpine-openbox passwd <new-password>" >&2; exit 1; }
        "$_PA" "$_G" passwd "$2" && echo "Password updated (restart to apply: stop, then start)."
        ;;
    *) echo "usage: alpine-openbox {start|stop|status|guide|logs|passwd <pw>}"; exit 1 ;;
esac
WRAP
    sed -i -e "s|__PA__|$_pa|g" -e "s|__LOG__|$_logfile|g" "$_wrapper"
    chmod +x "$_wrapper"

    _ok "alpine-openbox installed successfully."
    if [ "$_pw" = "123456" ]; then
        _log "⚠️ Using the default VNC password (123456). Change it: alpine-openbox passwd <new-password>"
    fi
    _log "Start the desktop with: alpine-openbox start"
}

_remove() {
    _log "Removing alpine-openbox..."
    _pa="$SHILL_CORE/bin/proot-alpine"
    _root="$SHILL_CORE/lib/proot-alpine"

    # Stop the desktop if it is running
    [ -x "$_pa" ] && [ -x "$_root/usr/local/bin/shill-openbox" ] \
        && "$_pa" /usr/local/bin/shill-openbox stop >/dev/null 2>&1 || true

    # Remove added symlink before apk del so novnc directory can be cleaned
    rm -f "$_root/usr/share/novnc/index.html"

    # Remove the apk virtual group (and its now-unneeded dependencies)
    if [ -x "$_pa" ] && [ -d "$_root" ]; then
        "$_pa" /sbin/apk del "$_VIRT" >/dev/null 2>&1 \
            || _log "⚠️ Could not remove apk packages (non-critical)."
    fi

    rm -f "$SHILL_CORE/bin/alpine-openbox" \
          "$SHILL_CORE/cache/alpine-openbox.log" \
          "$_root/usr/local/bin/shill-openbox" \
          "$_root/usr/local/bin/x-terminal-emulator" \
          "$_root/root/.vnc/xstartup" \
          "$_root/root/.vnc/passwd" \
          "$_root/root/.Xresources"
    rm -rf "$_root/root/.config/tint2"
    rmdir  "$_root/root/.vnc" 2>/dev/null || true
    rm -rf /tmp/shill-openbox /tmp/.X1-lock /tmp/.X11-unix/X1 /tmp/runtime-0

    _ok "alpine-openbox removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
