#!/usr/bin/env bash

# Docker packages bundler
# Purpose: Extract multiple packages, strip /data/adb paths, and combine into a single Docker archive
# Handles special filenames with colons by renaming before extraction

set -eo pipefail # Exit immediately if command fails
trap 'echo "Error occurred at line $LINENO"; cleanup' ERR

STAGING_DIR="staging_$(date +%s)"
OUTPUT_FILE="package.tar.xz"
STRIP_PATH="/data/qemu"
PACKAGES=(
    "qemu-system-x86_64-headless"
    "ncurses"
    "dtc"
    "glib"
    "libbz2" 
    "libcurl" 
    "libgmp"
    "libgnutls"
    "libiconv"
    "libjpeg-turbo"
    "liblzo"
    "libnettle"
    "libnfs"
    "libpixman"
    "libpng"
    "libslirp"
    "libspice-server"
    "libssh"
    "libusb"
    "libusbredir"
    "ncurses"
    "pulseaudio"
    "qemu-common"
    "resolv-conf"
    "zlib"
    "zstd"
)

dir=$(pwd)

# Setup logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    if [ -d "$STAGING_DIR" ]; then
        rm -rf "$STAGING_DIR"
    fi
    log "Cleanup completed"
}

# Find package files that match the base name
find_package_files() {
    local pkg_name="$1"
    local found_files=()

    if compgen -G "${pkg_name}-*.tar*" >/dev/null; then
        found_files+=("${pkg_name}-"*.pkg.tar.xz)
    fi

    for file in "${found_files[@]}"; do
        echo "$file"
    done
}

# Extract packages and strip /data/adb paths
extract_packages() {
    log "Creating temporary directories"
    mkdir -p "$STAGING_DIR"

    log "Beginning extraction and processing of packages..."

    for package in "${PACKAGES[@]}"; do
        log "Searching for package: $package"

        # Find package files using custom function
        readarray -t package_files < <(find_package_files "$package")

        if [ ${#package_files[@]} -eq 0 ]; then
            log "Warning: No files found for package '$package', skipping"
            continue
        fi

        for pkg_file in "${package_files[@]}"; do
            if [ -f "$pkg_file" ]; then
                log "Processing file: $pkg_file"

                if [[ "$pkg_file" == *:* ]]; then
                    new_filename="${pkg_file//:/}"
                    mv "$pkg_file" "$new_filename"
                    pkg_file="$new_filename"
                fi

                if [[ "$pkg_file" == *.tar.xz ]]; then
                    tar -xf "$pkg_file" -C "$STAGING_DIR" || {
                        log "Error: Failed to extract $pkg_file"
                        continue
                    }
                else
                    log "Error: Unsupported archive format for $pkg_file"
                    continue
                fi
            fi
        done
    done

    log "Extraction and processing completed successfully"
}


create_archive() {
    log "Creating final archive: $OUTPUT_FILE"

    if [ -f "$OUTPUT_FILE" ]; then
        log "Warning: Overwriting existing $OUTPUT_FILE"
        rm -f "$OUTPUT_FILE"
    fi

    tar -cJf "$OUTPUT_FILE" -C "$STAGING_DIR$STRIP_PATH" . || {
        log "Error: Failed to create $OUTPUT_FILE"
        return 1
    }

    if [ -f "$OUTPUT_FILE" ]; then
        size=$(du -h "$OUTPUT_FILE" | cut -f1)
        log "Successfully created $OUTPUT_FILE (Size: $size)"
        log "Contents summary:"
        tar -tf "$OUTPUT_FILE" | grep -v "/$" | wc -l | xargs -I{} echo "  {} files"
    else
        log "Error: Failed to create $OUTPUT_FILE"
        return 1
    fi
}


main() {
    log "=== Docker Package Bundling Script ==="
    log "Starting process at $(date)"

    extract_packages
    create_archive
    log "All operations completed successfully"
}

main
exit 0