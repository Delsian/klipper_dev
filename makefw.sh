#!/bin/sh
# Klipper firmware build script
# Usage: ./makefw.sh [ebb|skr]
#   ebb - Build only for EBB36 board
#   skr - Build only for SKR Mini v1.3 board
#   no arg - Build for both boards

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo "${YELLOW}[WARNING]${NC} $1"
}

build_ebb() {
    print_info "Building firmware for EBB36..."
    make clean KCONFIG_CONFIG=.config.ebb
    echo q | make menuconfig KCONFIG_CONFIG=.config.ebb
    make KCONFIG_CONFIG=.config.ebb
    print_info "Flashing EBB36 via CAN (UUID: d929e5aab5a4)..."
    python ../katapult/scripts/flashtool.py -u d929e5aab5a4 -f out/klipper.bin
    print_info "EBB36 build and flash complete!"
}

build_skr() {
    print_info "Building firmware for SKR Mini v1.3..."
    make clean KCONFIG_CONFIG=.config.skr
    echo q | make menuconfig KCONFIG_CONFIG=.config.skr
    make KCONFIG_CONFIG=.config.skr
    print_info "Flashing SKR Mini v1.3 via serial (/dev/ttyACM0)..."
    python ../katapult/scripts/flashtool.py -d /dev/ttyACM0 -f out/klipper.bin
    print_info "SKR Mini v1.3 build and flash complete!"
}

# Main script
case "${1:-both}" in
    ebb|e)
        build_ebb
        ;;
    skr|s)
        build_skr
        ;;
    both)
        build_ebb
        echo ""
        build_skr
        ;;
    *)
        print_error "Invalid argument: $1"
        echo "Usage: $0 [ebb|e|skr|s]"
        echo "  ebb|e  - Build only for EBB36 board"
        echo "  skr|s  - Build only for SKR Mini v1.3 board"
        echo "  (no arg) - Build for both boards"
        exit 1
        ;;
esac

print_info "All builds completed successfully!"