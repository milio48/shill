# Shill Package Manager (PM) Guide

This document serves as a System Map and Starter Kit for LLMs, Code Agents, and Developers to create and maintain Shill package installation scripts (`pm/*.sh`).

## Core Concepts

Shill is a portable, zero-dependency userspace environment. 
All packages installed through Shill **MUST** be portable, standalone binaries. They should not rely on system package managers (like `apt` or `yum`) or root privileges (`sudo`).

### Environment Variables
- `$SHILL_CORE`: The absolute path to the active Shill environment. **Every PM script MUST check if this is set** and use it as the base directory for all operations.

### Directory Structure
- `$SHILL_CORE/bin`: Target directory where the final executable binary MUST be placed.
- `$SHILL_CORE/cache`: Target directory for temporary downloads and extractions.

## Rules for PM Scripts

1. **Format**: Must be a standard POSIX shell script (`#!/bin/sh`) with `set -e` to exit on error.
2. **Naming**: The file must be named `<package-name>.sh` (e.g., `lazygit.sh`).
3. **Core Functions Required**:
   - `_install()`: Handles downloading, extracting, moving the binary to `$SHILL_CORE/bin/`, and cleaning up the cache.
   - `_remove()`: Deletes the binary from `$SHILL_CORE/bin/`.
4. **Output Functions Required**:
   - `_log()`: Standard informational logging (`printf '[shill:pkg] %s\n' "$*"`).
   - `_ok()`: Success logging (`printf '[shill:pkg] ✅ %s\n' "$*"`).
   - `_die()`: Error logging and script termination (`printf '[shill:pkg] ❌ %s\n' "$*" >&2; exit 1`).
5. **No Interactive Prompts**: The script must run silently without requiring user input.
6. **Architecture Detection**: Use `uname -s` and `uname -m` to dynamically map and download the correct binary for the user's system.
7. **Cleanup**: Always remove downloaded archives and extracted temp folders from `$SHILL_CORE/cache/` after installation.

## Registry

If you create a new PM script, you MUST perform two registry updates:

1. **Update `pm-ls.txt`**: Add the package using the format:
   ```text
   package_name:Short description of the package
   ```
2. **Update Root `README.md`**: You MUST also check and integrate the new package into the root `README.md` file under the `## 📦 Package Registry` section. Classify it under the appropriate category (e.g., Developer Tools, Utilities, Security) and add a row to the markdown table.

## Starter Kit / Boilerplate

Copy and paste the following template to create a new `pm/*.sh` script. Replace `[PKG_NAME]` and logic accordingly.

```sh
#!/bin/sh
# ==============================================================================
# Shill PM Installer: [PKG_NAME]
# [Short Description of the package]
# ==============================================================================

set -e

[PKG_NAME_UPPER]_VERSION="v1.0.0"

_log()  { printf '[shill:[PKG_NAME]] %s\n' "$*"; }
_die()  { printf '[shill:[PKG_NAME]] ❌ %s\n' "$*" >&2; exit 1; }
_ok()   { printf '[shill:[PKG_NAME]] ✅ %s\n' "$*"; }

[ -z "$SHILL_CORE" ] && _die "SHILL_CORE is not set."

_install() {
    _os_raw=$(uname -s)
    _arch_raw=$(uname -m)

    # 1. Map OS & Architecture to the target release format
    _os=""
    case "$_os_raw" in
        Linux)  _os="linux" ;;
        Darwin) _os="darwin" ;;
        *)      _die "Unsupported OS: $_os_raw" ;;
    esac

    _arch=""
    case "$_arch_raw" in
        x86_64|amd64)           _arch="amd64" ;;
        aarch64|arm64)          _arch="arm64" ;;
        *)                      _die "Unsupported architecture: $_arch_raw" ;;
    esac

    _target_bin="$SHILL_CORE/bin/[PKG_NAME]"
    _cache_dir="$SHILL_CORE/cache/[PKG_NAME]_dl"
    
    # Adjust variables according to actual release URL patterns
    _filename="[PKG_NAME]_${_os}_${_arch}.tar.gz"
    _url="https://example.com/download/${[PKG_NAME_UPPER]_VERSION}/${_filename}"

    _log "Installing [PKG_NAME] ${[PKG_NAME_UPPER]_VERSION} (${_os} ${_arch})..."

    # 2. Download
    mkdir -p "$_cache_dir"
    _archive_file="$_cache_dir/$_filename"

    _log "Downloading [PKG_NAME]..."
    curl -fsSL "$_url" -o "$_archive_file" || _die "Download failed."

    # 3. Extract
    _log "Extracting..."
    # Custom extraction logic here (tar -xzf, unzip, etc.)
    tar -xzf "$_archive_file" -C "$_cache_dir" || _die "Extraction failed."

    # 4. Install Binary
    _log "Installing binary..."
    _extracted_bin="$_cache_dir/[PKG_NAME]"
    
    if [ ! -f "$_extracted_bin" ]; then
        _die "Binary not found in extracted files."
    fi

    cp -f "$_extracted_bin" "$_target_bin"
    chmod +x "$_target_bin"

    # 5. Cleanup
    rm -rf "$_cache_dir"

    _ok "[PKG_NAME] installed successfully at $_target_bin"
}

_remove() {
    _log "Removing [PKG_NAME]..."
    rm -f "$SHILL_CORE/bin/[PKG_NAME]"
    _ok "[PKG_NAME] removed."
}

# --- Router ---
case "$1" in
    remove|uninstall) _remove ;;
    *) _install ;;
esac
```
