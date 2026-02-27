#!/bin/sh
# ==============================================================================
# Shill PM Installer: zfetch
# System, VPS, and Network info script optimized for restricted environments.
# ==============================================================================

set -e

_log()  { printf '[shill:zfetch] %s\n' "$*"; }
_die()  { printf '[shill:zfetch] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:zfetch] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _target="$SHILL_CORE/bin/zfetch"
    _log "Creating zfetch script..."

    # Create the zfetch binary (using sh for maximum compatibility in Shill)
    cat <<'EOF' > "$_target"
#!/bin/sh
# zfetch - A "to-the-point" system, VPS, and network info script.
# Optimized for BusyBox, Alpine, and restricted environments.

[ -z "$SHILL_CORE" ] && SHILL_CORE=$(dirname "$(dirname "$(readlink -f "$0")")")

print_info() {
    printf "%-14s : %s\n" "$1" "$2"
}

check_version() {
    if command -v "$2" >/dev/null 2>&1; then
        if [ "$2" = "wget" ]; then
            VERSION_OUTPUT=$(wget --help 2>&1 | head -n 1 | tr -d '\n\r')
        else
            VERSION_OUTPUT=$($2 $3 2>&1 | head -n 1 | tr -d '\n\r')
        fi
        print_info "$1" "$VERSION_OUTPUT"
    else
        print_info "$1" "Not Found"
    fi
}

check_service() {
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet "$1" 2>/dev/null; then echo "Active"; else echo "Inactive / Not Found"; fi
    else
        echo "N/A (no systemctl)"
    fi
}

# --- 1. System & OS ---
echo "--- System & OS ---"
print_info "Hostname" "$USER@$HOSTNAME"

OS_NAME=$(awk -F'"' '/PRETTY_NAME/ {print $2}' /etc/os-release 2>/dev/null)
[ -z "$OS_NAME" ] && OS_NAME=$(cat /etc/system-release 2>/dev/null)
[ -z "$OS_NAME" ] && OS_NAME=$(uname -o 2>/dev/null)
print_info "OS" "${OS_NAME:-N/A}"
print_info "Kernel" "$(uname -r)"
print_info "Architecture" "$(uname -m)"

UPTIME_VAL=$(uptime | awk -F, '{sub(/.*up /,"",$1); print $1}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
print_info "Uptime" "$UPTIME_VAL"

VIRT="N/A"
if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT_TEST=$(systemd-detect-virt 2>/dev/null)
    if [ "$VIRT_TEST" = "none" ]; then VIRT="Bare Metal"; else VIRT="$VIRT_TEST"; fi
elif [ -f /proc/cpuinfo ] && grep -q "hypervisor" /proc/cpuinfo; then
    VIRT="VM (Generic)"
elif [ -f /proc/self/cgroup ] && grep -q "docker" /proc/self/cgroup; then
    VIRT="Docker/Container"
fi
print_info "Virtualization" "$VIRT"

# --- 2. CPU & Processes ---
echo ""
echo "--- CPU & Processes ---"
if [ -f /proc/cpuinfo ]; then
    CPU_MODEL=$(awk -F': +' '/model name/ {print $2; exit}' /proc/cpuinfo)
    CPU_CORES=$(grep -c ^processor /proc/cpuinfo)
else
    CPU_MODEL="N/A"; CPU_CORES="N/A"
fi
print_info "CPU Model" "$CPU_MODEL"
print_info "CPU Cores" "$CPU_CORES"
print_info "Load Average" "$(uptime | awk -F'load average: ' '{print $2}')"

PROC_COUNT=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
print_info "Processes" "$PROC_COUNT"

# --- 3. Memory & Disk ---
echo ""
echo "--- Memory & Disk ---"
if [ -f /proc/meminfo ]; then
    TOTAL_MEM=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    FREE_MEM=$(awk '/MemFree/ {print $2}' /proc/meminfo)
    BUFFERS_MEM=$(awk '/Buffers/ {print $2}' /proc/meminfo)
    CACHED_MEM=$(awk '/^Cached/ {print $2}' /proc/meminfo)
    USED_MEM=$(( (TOTAL_MEM - FREE_MEM - BUFFERS_MEM - CACHED_MEM) / 1024 ))
    TOTAL_MEM_MB=$(( TOTAL_MEM / 1024 ))
    print_info "Memory" "$USED_MEM MiB / $TOTAL_MEM_MB MiB"

    SWAP_TOTAL=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
    if [ "$SWAP_TOTAL" -gt 0 ]; then
        SWAP_FREE=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
        SWAP_USED=$(( (SWAP_TOTAL - SWAP_FREE) / 1024 ))
        SWAP_TOTAL_MB=$(( SWAP_TOTAL / 1024 ))
        print_info "Swap" "$SWAP_USED MiB / $SWAP_TOTAL_MB MiB"
    else
        print_info "Swap" "Not Used"
    fi
else
    print_info "Memory" "$(free | awk '/Mem:/ {print $3 " / " $2}')"
fi
print_info "Disk (Root)" "$(df -h / 2>/dev/null | awk 'END{print $3 " / " $2 " (" $5 " used)"}')"
print_info "Inode (Root)" "$(df -i / 2>/dev/null | awk 'END{print $3 " / " $2 " (" $5 " used)"}')"

# --- 4. Network ---
echo ""
echo "--- Network ---"

IP_LOKAL=$(ip -4 addr show 2>/dev/null | awk '/inet / && !/127.0.0.1/ {split($2,a,"/"); print a[1]; exit}')
[ -z "$IP_LOKAL" ] && IP_LOKAL=$(hostname -i 2>/dev/null | awk '{print $1}')

IS_PRIVATE_IP=0
case "$IP_LOKAL" in
    10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*)
        IS_PRIVATE_IP=1
        IP_TYPE="Internal/NAT"
        ;;
    *)
        IP_TYPE="Public (Direct)"
        ;;
esac
print_info "Inbound IP" "${IP_LOKAL:-N/A} ($IP_TYPE)"

OUTBOUND_IP=""
if command -v curl >/dev/null 2>&1; then
    PUBLIC_INFO=$(curl -s --connect-timeout 3 ifconfig.me)
    if [ -n "$PUBLIC_INFO" ]; then
        OUTBOUND_IP="$PUBLIC_INFO"
        print_info "Outbound IP" "${OUTBOUND_IP:-N/A} (Seen by Internet)"
        
        if [ "$IS_PRIVATE_IP" -eq 1 ]; then
            print_info "  Note" "Server is behind NAT. Use Outbound IP for DNS/A-Record."
        elif [ "$IP_LOKAL" != "$OUTBOUND_IP" ]; then
             print_info "  Note" "IP Mismatch detected (Transparent Proxy/VPN)."
        fi
    else
        print_info "Outbound IP" "Failed to fetch"
    fi
else
    print_info "Outbound IP" "N/A (curl missing)"
fi
print_info "DNS Servers" "$(awk '/^nameserver/ {print $2}' /etc/resolv.conf 2>/dev/null | tr '\n' ' ')"

PORT_LIST=$(netstat -tln 2>/dev/null | awk '/LISTEN/ {n=split($4,a,":"); print a[n]}' | sort -nu)
PORTS_FORMATTED=""
if [ -n "$PORT_LIST" ] && [ -r /etc/services ]; then
    while read -r port; do
        SERVICE_NAME=$(awk -v p="$port" '$2 == p"/tcp" {print $1; exit}' /etc/services 2>/dev/null)
        if [ -z "$SERVICE_NAME" ]; then PORTS_FORMATTED="$PORTS_FORMATTED$port, "; else PORTS_FORMATTED="$PORTS_FORMATTED$port ($SERVICE_NAME), "; fi
    done <<EOF
$PORT_LIST
EOF
    PORTS_FORMATTED=$(echo "$PORTS_FORMATTED" | sed 's/, $//')
elif [ -n "$PORT_LIST" ]; then
    # Paste equivalent
    for p in $PORT_LIST; do PORTS_FORMATTED="$PORTS_FORMATTED$p, "; done
    PORTS_FORMATTED=$(echo "$PORTS_FORMATTED" | sed 's/, $//')
else
    PORTS_FORMATTED="N/A"
fi
print_info "Open Ports" "${PORTS_FORMATTED:-N/A}"

echo ""
echo "--- Active Connections (TCP) ---"
if command -v netstat >/dev/null 2>&1; then
    netstat -tn 2>/dev/null | grep ESTAB | head -n 5
elif command -v ss >/dev/null 2>&1; then
    ss -tn 2>/dev/null | grep ESTAB | head -n 5
else
    echo "  N/A"
fi

# --- 5. Service Status ---
echo ""
echo "--- Service Status (systemd) ---"
if command -v systemctl >/dev/null 2>&1; then
    for s in sshd nginx apache2 httpd mysql mariadb docker redis ufw firewalld; do
        if systemctl list-units --full -all 2>/dev/null | grep -q "${s}.service"; then
            print_info "$s" "$(if systemctl is-active --quiet $s 2>/dev/null; then echo "Active"; else echo "Inactive"; fi)"
        fi
    done
else
    print_info "Services" "N/A (systemctl not found)"
fi

# --- 6. Software Versions ---
echo ""
echo "--- Software Versions ---"
if command -v python3 >/dev/null 2>&1; then check_version "Python" "python3" "--version"; elif command -v python >/dev/null 2>&1; then check_version "Python" "python" "--version"; else print_info "Python" "Not Found"; fi
check_version "Node.js" "node" "--version"
check_version "NPM" "npm" "--version"
check_version "PHP" "php" "--version"
check_version "Git" "git" "--version"
check_version "Curl" "curl" "--version"
check_version "Wget" "wget" "--version"
check_version "Docker" "docker" "--version"
check_version "Java" "java" "-version"

# --- 7. Directory Info ---
echo ""
echo "--- Directory Info ---"
print_info "Current Dir" "$PWD"
if command -v du >/dev/null 2>&1; then
    print_info "Home Usage" "$(du -sh "$HOME" 2>/dev/null | tail -n 1 | awk '{print $1}')"
    print_info "Temp Usage" "$(du -sh /tmp 2>/dev/null | tail -n 1 | awk '{print $1}')"
else
    print_info "Home Usage" "N/A"; print_info "Temp Usage" "N/A"
fi
WRITABLE_DIRS=""
[ -w "$HOME" ] && WRITABLE_DIRS="$WRITABLE_DIRS$HOME, "
[ -w "." ] && [ "$PWD" != "$HOME" ] && WRITABLE_DIRS="$WRITABLE_DIRS. (current), "
[ -w "/tmp" ] && WRITABLE_DIRS="$WRITABLE_DIRS/tmp, "
[ -w "/var/tmp" ] && WRITABLE_DIRS="$WRITABLE_DIRS/var/tmp, "
CLEANED_DIRS=$(echo "$WRITABLE_DIRS" | sed 's/, $//')
print_info "Writable Dirs" "${CLEANED_DIRS:-N/A}"

# --- 8. User & Environment ---
echo ""
echo "--- User & Environment ---"
print_info "ID / Groups" "$(id 2>/dev/null || echo 'N/A')"
if command -v whoami >/dev/null 2>&1; then
    print_info "Username" "$(whoami)"
fi
print_info "Shell" "$(basename "$SHELL" 2>/dev/null || echo 'N/A')"
print_info "Open Files" "$(ulimit -n 2>/dev/null || echo 'N/A')"
if command -v who >/dev/null 2>&1; then print_info "Active Users" "$(who 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ')"; else print_info "Active Users" "N/A"; fi

# --- 10. Top Processes ---
echo ""
echo "--- Top Processes (by CPU/Mem) ---"
if command -v top >/dev/null 2>&1; then
    top -b -n 1 2>/dev/null | head -n 12
else
    if command -v ps >/dev/null 2>&1; then
        ps -o pid,user,vsz,args 2>/dev/null | head -n 6
    else
        print_info "Top Processes" "N/A (ps/top required)"
    fi
fi

# --- 11. Security Monitor ---
echo ""
echo "--- Security Monitor ---"
echo "Recent Files (last 60 min):"
if command -v find >/dev/null 2>&1; then
    find "$HOME" /tmp -mmin -60 -type f 2>/dev/null | head -n 5
else
    echo "  N/A (find missing)"
fi

echo ""
echo "Suspicious SUID/SGID Files:"
if command -v find >/dev/null 2>&1; then
    find "$HOME" /tmp -maxdepth 3 -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null || echo "  None found."
else
    echo "  N/A (find missing)"
fi

# --- 14. Miscellaneous ---
echo ""
echo "--- Miscellaneous ---"
PKG_COUNT="N/A"
if command -v dpkg >/dev/null 2>&1; then PKG_COUNT="$(dpkg-query -f '.\n' -W 2>/dev/null | wc -l) (dpkg)"; elif command -v rpm >/dev/null 2>&1; then PKG_COUNT="$(rpm -qa 2>/dev/null | wc -l) (rpm)"; elif command -v apk >/dev/null 2>&1; then PKG_COUNT="$(apk info 2>/dev/null | wc -l) (apk)"; fi
print_info "Packages" "$PKG_COUNT"
print_info "Date" "$(date)"
echo ""
EOF

    chmod +x "$_target"
    _ok "zfetch installed at $SHILL_CORE/bin/zfetch"
}

_remove() {
    _log "Removing zfetch..."
    rm -f "$SHILL_CORE/bin/zfetch"
    _ok "zfetch removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
