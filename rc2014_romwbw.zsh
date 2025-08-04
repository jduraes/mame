#!/usr/bin/env zsh

# RC2014 RomWBW MAME Setup Script
# 
# This script launches a MAME RC2014 emulation with RomWBW ROM
# and connects it to minicom for terminal access
#
# RULE: Do not recompile RomWBW or change its settings - it's ready
# to output to a serial terminal.
#
# Hardware configuration:
# - RC2014 Zed Pro (12-slot extended backplane)
# - Z80 2.1 CPU Module  
# - Dual Clock Module
# - 512K ROM / 512K RAM Module (loaded with RomWBW)
# - Dual Serial SIO/2 Module
# - Compact Flash Module (with 1k combo image)
# - Serial connection via TCP socket for minicom

set -e

# Configuration
ROMWBW_PATH="/Users/mduraes/Documents/GitHub/RomWBW/Binary"
ROMWBW_ROM="RCZ80_std.rom"
MAME_SYSTEM="rc2014zedp"
TCP_PORT="1234"
ROM_BIOS="3.0.1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}RC2014 RomWBW MAME Setup${NC}"
echo "========================="

# Check if RomWBW ROM exists
if [[ ! -f "${ROMWBW_PATH}/${ROMWBW_ROM}" ]]; then
    echo -e "${RED}Error: RomWBW ROM not found at ${ROMWBW_PATH}/${ROMWBW_ROM}${NC}"
    exit 1
fi

# Check if MAME is available
if ! command -v mame &> /dev/null; then
    echo -e "${RED}Error: MAME not found in PATH${NC}"
    exit 1
fi

# Check if minicom is available
if ! command -v minicom &> /dev/null; then
    echo -e "${RED}Error: minicom not found in PATH${NC}"
    echo "Install with: brew install minicom"
    exit 1
fi

# Check if port is already in use
if lsof -i :${TCP_PORT} &> /dev/null; then
    echo -e "${YELLOW}Warning: Port ${TCP_PORT} is already in use${NC}"
    read "response?Continue anyway? (y/N): "
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}Configuration:${NC}"
echo "  System: ${MAME_SYSTEM}"
echo "  ROM: ${ROMWBW_ROM} (BIOS: ${ROM_BIOS})"
echo "  CF Card: hd1k_combo.img"
echo "  TCP Port: ${TCP_PORT}"
echo "  Serial: 115200 8N1"
echo ""

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    if [[ -n $MAME_PID ]]; then
        kill $MAME_PID 2>/dev/null
    fi
    if [[ -n $MINICOM_PID ]]; then
        kill $MINICOM_PID 2>/dev/null
    fi
}

trap cleanup EXIT INT TERM

# Start MAME in background
echo -e "${BLUE}Starting MAME RC2014 emulation...${NC}"

# Ensure roms directory exists and setup ROM symlink
mkdir -p roms/rc2014_rom_ram_512k
ln -sf "${ROMWBW_PATH}/${ROMWBW_ROM}" roms/rc2014_rom_ram_512k/rcz80_std_3_0_1.rom
ln -sf "${ROMWBW_PATH}/hd1k_combo.img" roms/hd1k_combo.img

MAME_CMD=(
    mame
    $MAME_SYSTEM
    -bus:1 z80_21
    -bus:2 dual_clk
    -bus:3 rom_ram
    -bus:4 sio
    -bus:5 cf
    -bus:4:sio:rs232a null_modem
    -harddisk roms/hd1k_combo.img
    -bitb socket.localhost:${TCP_PORT}
    -skip_gameinfo
    -window
    -keepaspect
)

echo "MAME command: ${MAME_CMD[*]}"
echo ""

"${MAME_CMD[@]}" &
MAME_PID=$!

# Wait a moment for MAME to start up
echo -e "${YELLOW}Waiting for MAME to start...${NC}"
sleep 5

# Check if MAME is still running
if ! kill -0 $MAME_PID 2>/dev/null; then
    echo -e "${RED}Error: MAME failed to start${NC}"
    exit 1
fi

# Wait for the TCP port to be available
echo -e "${YELLOW}Waiting for TCP port ${TCP_PORT} to be available...${NC}"
for i in {1..10}; do
    if nc -z localhost ${TCP_PORT} 2>/dev/null; then
        echo -e "${GREEN}TCP port ${TCP_PORT} is ready${NC}"
        break
    fi
    if [[ $i -eq 10 ]]; then
        echo -e "${RED}Error: TCP port ${TCP_PORT} not available after 10 seconds${NC}"
        exit 1
    fi
    sleep 1
done

echo ""
echo -e "${GREEN}Starting minicom terminal emulator...${NC}"
echo -e "${YELLOW}minicom settings: 115200 8N1, TCP connection to localhost:${TCP_PORT}${NC}"
echo ""
echo -e "${BLUE}Tips:${NC}"
echo "  - RomWBW should boot automatically"  
echo "  - Use Ctrl-A Z for minicom help"
echo "  - Use Ctrl-A X to exit minicom"
echo "  - The script will cleanup MAME when you exit"
echo ""

# Start minicom with TCP connection
# Use direct TCP connection with minicom
minicom -C minicom.log -o -c on -D "tcp:localhost:${TCP_PORT}" -b 115200

echo -e "\n${GREEN}Session ended${NC}"
