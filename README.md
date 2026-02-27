# 🏴‍☠️ Shill — Portable Standarized Userspace

> *"The Stowaway"* — Zero-dependency, self-modifying, procedural Linux environment manager.

Shill is a single POSIX shell script that bootstraps a **fully isolated, portable userspace** on any Linux server — even the most restricted shared hosting. No root, no `sudo`, no package manager required.

## ⚡ Quick Start

```bash
# 1. Clone the repo (or just download shill.sh)
git clone https://github.com/<OWNER>/shill.git
cd shill

# 2. Make it executable
chmod +x shill.sh

# 3. Run it (first run triggers setup)
./shill.sh
```

On first run, Shill will:
1. Ask you where to install (e.g. `~/.shill`)
2. Download static binaries: **curl**, **bash**, **busybox**
3. Fetch official **CA certificates** (`cacert.pem`) for secure downloads
4. Build a **symlink farm** with hundreds of Linux commands
5. Save the configuration permanently inside the script itself

## 🎮 Commands

| Command | Description |
|---------|-------------|
| `./shill.sh setup` | Force re-run setup (download binaries, rebuild symlinks) |
| `./shill.sh enter` | Launch interactive shell with arrow keys & history |
| `./shill.sh space <cmd>` | Run a single command in Shill environment |
| `./shill.sh ls` | List installed & available packages |
| `./shill.sh install <pkg>` | Install a package from the registry |
| `./shill.sh remove <pkg>` | Remove an installed package (cleanly) |
| `./shill.sh destroy` | Wipe everything (with confirmation) |
| `./shill.sh help` | Show help |

## 📦 Package Registry

Packages are grouped by category for easier navigation. Install any package using `./shill.sh install <name>`.

### 🛠️ Developer Tools
| Name | Description |
|------|-------------|
| `node` | Node.js runtime (official LTS) with npm & npx |
| `frankenphp` | FrankenPHP standalone server (PHP 8.2) |
| `php` | Static PHP CLI binary (from static-php.dev) |
| `webi` | WebInstall (webinstall.dev) manager |
| `make` | GNU Make build tool |
| `jq` | Lightweight JSON processor |

### 🔧 Utilities
| Name | Description |
|------|-------------|
| `tmux` | Terminal multiplexer |
| `pm2-go` | Process manager in Go (PM2 alternative) |
| `screen` | GNU Screen terminal multiplexer |
| `rsync` | Fast file sync utility |
| `zfetch` | System & Network info fetch script |
| `bench` | System benchmark script (by TeddySun) |
| `less` | Terminal pager |
| `ag` | The Silver Searcher (fast grep) |
| `socat` | Multipurpose relay (SOcket CAT) |

### 🛡️ Security & Remote
| Name | Description |
|------|-------------|
| `sshx` | Fast, collaborative terminal sharing |
| `ngrok` | Reverse proxy for local exposure |
| `pinggy` | SSH-based tunnel for local exposure |
| `linpeas` | Privilege escalation enumeration tool |
| `deepce` | Docker enumeration and exploitation tool |
| `dropbearmulti` | SSH server/client (Dropbear) |

## 🏗️ Default Packages (Built-in)

The following commands are available immediately after setup, provided by the core **Bash**, **Curl**, and the **BusyBox** symlink farm:

`curl`, `[`, `[[`, `acpid`, `add-shell`, `addgroup`, `adduser`, `adjtimex`, `ar`, `arch`, `arp`, `arping`, `ascii`, `ash`, `awk`, `base32`, `base64`, `basename`, `bash`, `bbconfig`, `bc`, `beep`, `blkdiscard`, `blkid`, `blockdev`, `bootchartd`, `brctl`, `bunzip2`, `bzcat`, `bzip2`, `cal`, `cat`, `chat`, `chattr`, `chgrp`, `chmod`, `chown`, `chpasswd`, `chpst`, `chroot`, `chrt`, `chvt`, `cksum`, `clear`, `cmp`, `comm`, `conspy`, `cp`, `cpio`, `crc32`, `crond`, `crontab`, `cryptpw`, `cttyhack`, `cut`, `date`, `dc`, `dd`, `deallocvt`, `delgroup`, `deluser`, `depmod`, `devmem`, `df`, `dhcprelay`, `diff`, `dirname`, `dmesg`, `dnsd`, `dnsdomainname`, `dos2unix`, `dpkg`, `dpkg-deb`, `du`, `dumpkmap`, `dumpleases`, `echo`, `ed`, `egrep`, `eject`, `env`, `envdir`, `envuidgid`, `ether-wake`, `expand`, `expr`, `factor`, `fakeidentd`, `fallocate`, `false`, `fatattr`, `fbset`, `fbsplash`, `fdflush`, `fdformat`, `fdisk`, `fgconsole`, `fgrep`, `find`, `findfs`, `flock`, `fold`, `free`, `freeramdisk`, `fsck`, `fsck.minix`, `fsfreeze`, `fstrim`, `fsync`, `ftpd`, `ftpget`, `ftpput`, `fuser`, `getfattr`, `getopt`, `getty`, `grep`, `groups`, `gunzip`, `gzip`, `halt`, `hd`, `hdparm`, `head`, `hexdump`, `hexedit`, `hostid`, `hostname`, `httpd`, `hush`, `hwclock`, `i2cdetect`, `i2cdump`, `i2cget`, `i2cset`, `i2ctransfer`, `id`, `ifconfig`, `ifdown`, `ifenslave`, `ifup`, `inetd`, `init`, `inotifyd`, `insmod`, `install`, `ionice`, `iostat`, `ip`, `ipaddr`, `ipcalc`, `ipcrm`, `ipcs`, `iplink`, `ipneigh`, `iproute`, `iprule`, `iptunnel`, `kbd_mode`, `kill`, `killall`, `killall5`, `klogd`, `last`, `less`, `link`, `linux32`, `linux64`, `linuxrc`, `ln`, `loadfont`, `loadkmap`, `logger`, `login`, `logname`, `logread`, `losetup`, `lpd`, `lpq`, `lpr`, `ls`, `lsattr`, `lsmod`, `lsof`, `lspci`, `lsscsi`, `lsusb`, `lzcat`, `lzma`, `lzop`, `lzopcat`, `makedevs`, `makemime`, `man`, `md5sum`, `mdev`, `mesg`, `microcom`, `mim`, `minips`, `mkdir`, `mkdosfs`, `mke2fs`, `mkfifo`, `mkfs.ext2`, `mkfs.minix`, `mkfs.vfat`, `mknod`, `mkpasswd`, `mkswap`, `mktemp`, `modinfo`, `modprobe`, `more`, `mount`, `mountpoint`, `mpstat`, `mt`, `mv`, `nameif`, `nanddump`, `nandwrite`, `nbd-client`, `nc`, `netcat`, `netstat`, `nice`, `nl`, `nmeter`, `nohup`, `nologin`, `nproc`, `nsenter`, `nslookup`, `ntpd`, `od`, `openvt`, `partprobe`, `passwd`, `paste`, `patch`, `pgrep`, `pidof`, `ping`, `ping6`, `pipe_progress`, `pivot_root`, `pkill`, `pmap`, `popmaildir`, `poweroff`, `powertop`, `printenv`, `printf`, `ps`, `pscan`, `pstree`, `pwd`, `pwdx`, `raidautorun`, `rdate`, `rdev`, `readahead`, `readlink`, `readprofile`, `realpath`, `reboot`, `reformime`, `remove-shell`, `renice`, `reset`, `resize`, `resume`, `rev`, `rm`, `rmdir`, `rmmod`, `route`, `rpm`, `rpm2cpio`, `rtcwake`, `run-init`, `run-parts`, `runlevel`, `runsv`, `runsvdir`, `rx`, `script`, `scriptreplay`, `sed`, `seedrng`, `sendmail`, `seq`, `setarch`, `setconsole`, `setfattr`, `setfont`, `setkeycodes`, `setlogcons`, `setpriv`, `setserial`, `setsid`, `setuidgid`, `sh`, `sha1sum`, `sha256sum`, `sha3sum`, `sha512sum`, `showkey`, `shred`, `shuf`, `slattach`, `sleep`, `smemcap`, `softlimit`, `sort`, `split`, `ssl_client`, `start-stop-daemon`, `stat`, `strings`, `stty`, `su`, `sulogin`, `sum`, `sv`, `svc`, `svlogd`, `svok`, `swapoff`, `swapon`, `switch_root`, `sync`, `sysctl`, `syslogd`, `tac`, `tail`, `tar`, `taskset`, `tc`, `tcpsvd`, `tee`, `telnet`, `telnetd`, `test`, `tftp`, `tftpd`, `time`, `timeout`, `top`, `touch`, `tr`, `traceroute`, `traceroute6`, `tree`, `true`, `truncate`, `ts`, `tsort`, `tty`, `ttysize`, `tunctl`, `tune2fs`, `ubiattach`, `ubidetach`, `ubimkvol`, `ubirename`, `ubirmvol`, `ubirsvol`, `ubiupdatevol`, `udhcpc`, `udhcpc6`, `udhcpd`, `udpsvd`, `uevent`, `umount`, `uname`, `uncompress`, `unexpand`, `uniq`, `unix2dos`, `unlink`, `unlzma`, `unlzop`, `unshare`, `unxz`, `unzip`, `uptime`, `users`, `usleep`, `uudecode`, `uuencode`, `vconfig`, `vi`, `vlock`, `volname`, `w`, `wall`, `watch`, `watchdog`, `wc`, `wget`, `which`, `who`, `whoami`, `whois`, `xargs`, `xxd`, `xzcat`, `yes`, `zcat`, `zcip`

## 🛡️ How It Survives

Shill includes a **10-Layer Brute-Force Downloader** that tries every possible tool on the host system to download files:

1. `curl` → 2. `wget` → 3. `python` → 4. `perl` → 5. `php` → 6. `ruby` → 7. `node` → 8. `openssl` → 9. `socat` → 10. `bash /dev/tcp`

## 📂 Directory Structure

After setup, your chosen directory will contain:

```
$SHILL_CORE/
├── bin/              # Standalone binaries (bash, curl, installed packages)
├── etc/              # Configuration files (cacert.pem, etc.)
├── busybox_links/    # Symlink farm (hundreds of commands → busybox)
├── lib/              # Library files (e.g. node_modules)
├── cache/            # Temporary download folder
├── .shill_history    # Isolated bash history
└── .shill_rc         # Isolated bash config
```

## 🔧 Adding Custom Packages

Create a new `pm/<name>.sh` installer script that supports `install` and `remove` commands:

```bash
#!/bin/sh
_install() {
    # Download your binary
    curl -fsSL "https://example.com/binary" -o "$SHILL_CORE/bin/<name>"
    chmod +x "$SHILL_CORE/bin/<name>"
}

_remove() {
    rm -f "$SHILL_CORE/bin/<name>"
}

case "$1" in
    remove) _remove ;;
    *) _install ;;
esac
```

---