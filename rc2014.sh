#!/usr/bin/env zsh

# RC2014 RomWBW MAME Setup Script (with YM2149 sound on slot 6 and RTC on slot 7)
#
# Launches RC2014 Zed Pro with RomWBW and built-in MAME terminal.
# Adds a YM2149 sound card on bus slot 6 so audio is enabled, and a DS1302 RTC on slot 7.
#
# Hardware configuration:
# - RC2014 Zed Pro (12-slot extended backplane)
# - Slot 1: Z80 2.1 CPU Module
# - Slot 2: Dual Clock Module
# - Slot 3: 512K ROM / 512K RAM (RomWBW)
# - Slot 4: Dual Serial SIO/2
# - Slot 5: Compact Flash
# - Slot 6: YM2149 sound card
# - Slot 7: DS1302 RTC
#
# Note ("holly grail"):
# This script, with the RS-232 configured as:
#   -bus:4:sio:rs232a null_modem -bitb socket.localhost:1234
# allows connecting with minicom directly over a TCP socket, e.g.:
#   minicom -o -D "tcp:localhost:1234" -b 115200
# No socat is required.

set -euo pipefail

# Configuration
ROMWBW_PATH="/Users/mduraes/Documents/GitHub/RomWBW/Binary"
ROMWBW_ROM="RCZ80_std.rom"
MAME_SYSTEM="rc2014zedp"
ROM_BIOS="3.0.1"

# Check assets
if [[ ! -f "${ROMWBW_PATH}/${ROMWBW_ROM}" ]]; then
  echo "Error: RomWBW ROM not found at ${ROMWBW_PATH}/${ROMWBW_ROM}" 1>&2
  exit 1
fi

if ! command -v mame >/dev/null 2>&1; then
  echo "Error: MAME not found in PATH" 1>&2
  exit 1
fi

# Ensure roms directory and links
mkdir -p roms/rc2014_rom_ram_512k
ln -sf "${ROMWBW_PATH}/${ROMWBW_ROM}" "roms/rc2014_rom_ram_512k/rcz80_std_3_0_1.rom"
ln -sf "${ROMWBW_PATH}/hd1k_combo.img" "roms/hd1k_combo.img"

# Build MAME command
MAME_CMD=(
  mame
  "$MAME_SYSTEM"
  -bus:1 z80_21
  -bus:2 dual_clk
  -bus:3 rom_ram
  -bus:4 sio
  -bus:5 cf
  -bus:6 ym_sound
  -bus:7 rtc
  -bus:4:sio:rs232a null_modem
  -bitb socket.localhost:1234
  -harddisk roms/hd1k_combo.img
  -skip_gameinfo
  -window
  -keepaspect
  -volume 1
)
echo "MAME command: ${MAME_CMD[*]}"
exec "${MAME_CMD[@]}"

