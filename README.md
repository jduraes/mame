# RC2014 on MAME

This repository includes a helper script to launch an RC2014 Zed Pro configuration under MAME with RomWBW and working audio, plus TCP-based terminal access that works with ANSI-capable terminals.

How to run:
- Build or install MAME so the `mame` binary is on your PATH.
- Ensure RomWBW binaries exist at: `/Users/mduraes/Documents/GitHub/RomWBW/Binary/RCZ80_std.rom`.
- From the repo root, run:
  ./rc2014.sh

Notes:
- Audio: YM2149 sound card is attached (slot 6) and RTC module (slot 7).
- Terminal over TCP ("holly grail"): RS-232 is wired via TCP null modem on localhost:1234. You can connect with minicom without socat:
  minicom -o -D "tcp:localhost:1234" -b 115200
- If you need to force the audio backend on macOS:
  ./rc2014.sh -sound portaudio -pa_list_devices
  ./rc2014.sh -sound portaudio -pa_out_device "Built-in Output"

Troubleshooting:
- If ROM checksum warnings appear, they are expected for local builds; this project ignores checksum prompts by design.
- For ANSI rendering, use the TCP method above instead of the built-in MAME terminal.

