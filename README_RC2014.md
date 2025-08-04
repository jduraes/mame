# RC2014 RomWBW MAME Setup

This directory contains a script to run RC2014 emulation with RomWBW using MAME and minicom on macOS.

## Overview

The `rc2014_romwbw.zsh` script sets up a complete RC2014 system emulation using:

- **MAME**: RC2014 Zed Pro hardware emulation
- **RomWBW**: Z80 retro computing ROM/BIOS (from RomWBW repository)
- **minicom**: Terminal emulator for serial connection
- **1K Combo**: Compact Flash image with development tools and games

## Hardware Configuration

- RC2014 Zed Pro (12-slot extended backplane)
- Z80 2.1 CPU Module (Slot 1)
- Dual Clock Module (Slot 2)
- 512K ROM/RAM Module with RomWBW (Slot 3)
- Dual Serial SIO/2 Module (Slot 4)
- Compact Flash Module with 1K combo image (Slot 5)

## Prerequisites

1. **MAME**: Build and install MAME in your PATH
2. **minicom**: Install via `brew install minicom`
3. **RomWBW**: Clone RomWBW repository to `/Users/mduraes/Documents/GitHub/RomWBW`
4. **Network tools**: `nc` (netcat) and `lsof` (usually pre-installed on macOS)

## Usage

```bash
./rc2014_romwbw.zsh
```

The script will:
1. Check for required dependencies
2. Set up ROM and disk image symlinks
3. Launch MAME in windowed mode
4. Wait for system initialization
5. Connect minicom to the emulated serial port
6. Present you with the RomWBW boot prompt

## Features

- **Windowed MAME**: Visual representation of the RC2014 system
- **Serial Terminal**: Full terminal functionality via minicom
- **Session logging**: All terminal output saved to `minicom.log`
- **Auto-cleanup**: MAME process cleaned up on exit
- **Error checking**: Validates dependencies and port availability

## Controls

### MAME Window
- Standard MAME controls and menus available
- ESC: Access MAME menu
- Window can be resized and moved

### minicom Terminal
- **Ctrl-A Z**: Help menu
- **Ctrl-A X**: Exit minicom
- **Ctrl-A S**: Send files
- **Ctrl-A L**: Capture log file

## System Software

The RomWBW system includes:
- CP/M 2.2, CP/M 3, and ZSDOS
- Microsoft BASIC
- Development tools (assemblers, compilers)
- Games and utilities
- Disk and file management tools

## Troubleshooting

### Port 1234 in use
If TCP port 1234 is busy, either:
- Kill the process using the port
- Change `TCP_PORT` in the script

### ROM checksum warnings
MAME may show ROM checksum warnings. This is normal when using newer RomWBW versions and doesn't affect functionality.

### MAME fails to start
Check that:
- MAME is properly built and in PATH
- RomWBW ROM exists at expected location
- All required modules are available

## File Structure

```
/Users/mduraes/Documents/GitHub/mame/
├── rc2014_romwbw.zsh      # Main setup script
├── README_RC2014.md       # This file
├── roms/                  # Auto-created ROM directory
│   ├── rc2014_rom_ram_512k/
│   │   └── rcz80_std_3_0_1.rom  # RomWBW ROM symlink
│   └── hd1k_combo.img     # 1K combo CF image symlink
└── minicom.log            # Session log (created at runtime)
```

## Rule

**IMPORTANT**: Do not recompile RomWBW or change its settings. The ROM is ready to output to a serial terminal as configured.
