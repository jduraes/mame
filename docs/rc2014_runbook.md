RC2014 MAME + socat + minicom runbook

Purpose
- Document how run_rc2014.sh orchestrates MAME, socat, and minicom so we can quickly recover context in the future.

High-level flow
1) Pre-flight cleanup
   - Kills any lingering minicom using the configured PTY link
   - Kills any lingering socat instances bound to the PTY link or TCP port
   - Kills any running mame processes (best-effort, then force) to ensure a clean start
   - Removes stale PTY symlink and per-port lock directory

2) Single-instance lock (per TCP port)
   - Creates /tmp/mame-bridge-${PORT}.lock
   - Exits if another bridge for the same port is already running (unless --allow-multiple)

3) Capability checks
   - Verifies socat is installed
   - Warns if minicom is missing (still proceeds; you can connect with other tools)

4) Mode and listener logic
   - Default mode is `listen` (the bridge listens; MAME connects)
   - Alternative mode is `connect` (the bridge connects to a MAME listener)
   - If in connect mode and a listener isn’t detected on the port, it attempts to start MAME via rc2014.sh (if provided or auto-detected in the repo)
   - Records PIDs of MAME processes listening/connected on the port for clean shutdown later

5) Start the bridge (socat)
   - Spawns a background loop that maintains a PTY <-> TCP bridge
   - Creates a PTY at PTY_LINK (default /tmp/mame-tty) and either:
     - Listens on tcp-listen:${PORT} (listen mode), or
     - Connects to tcp:127.0.0.1:${PORT} (connect mode)
   - Auto-retries if the connection is dropped (e.g., MAME restarts)

6) Start MAME (when appropriate)
   - In listen mode, waits for socat to be LISTENing, then runs rc2014.sh if no MAME is already running
   - In connect mode, tries to ensure exactly one MAME instance is listening/connecting on the target port, pruning extras if needed

7) Start the terminal (minicom)
   - Launches: minicom -o -D "${PTY_LINK}" -b "${BAUD}" [extra args]
   - Watches socat: if the bridge dies (MAME quits), terminates minicom to avoid zombie sessions

8) Cleanup on exit
   - Trap cleans up background socat, removes PTY link, kills recorded MAME PIDs, and removes the lock directory

Key defaults
- PORT: 1234
- PTY_LINK: /tmp/mame-tty
- BAUD: 115200
- RC_SCRIPT: ./rc2014.sh if found and executable in repo root
- QUIET by default (logs to /tmp/mame-bridge-*.log)

How rc2014.sh is expected to run MAME
- Launches rc2014zedp with slots:
  -bus:1 z80_21 -bus:2 dual_clk -bus:3 rom_ram -bus:4 sio -bus:5 cf -bus:6 ym_sound -bus:7 rtc
- Wires RS-232A as a TCP null_modem and binds to localhost:1234:
  -bus:4:sio:rs232a null_modem -bitb socket.localhost:1234
- This means: MAME will open a TCP endpoint for the serial port, and external clients can connect by TCP.

Two ways to use the bridge
- Listen mode (default): socat listens; MAME connects out
  - Command: ./run_rc2014.sh [PORT] [PTY_LINK] [BAUD]
  - Flow: socat listens -> starts MAME (if not already running) -> minicom connects to PTY
- Connect mode: socat connects; MAME listens
  - Command: ./run_rc2014.sh -- rc-script ./rc2014.sh <PORT> <PTY_LINK> <BAUD>
  - Or implicitly if rc2014.sh is present and socat detects no listener

Quick start examples
1) Recommended simple path (use MAME’s TCP directly without a PTY):
   - Start MAME: ./rc2014.sh
   - Separate terminal: minicom -o -D "tcp:localhost:1234" -b 115200

2) Using the bridge/PTY path:
   - ./run_rc2014.sh 1234 /tmp/rc2014-tty 115200
   - This will:
     - Ensure no stray processes are running
     - Start a PTY at /tmp/rc2014-tty bridged to TCP:1234
     - Start MAME via rc2014.sh if needed
     - Launch minicom on /tmp/rc2014-tty

Operational tips
- If you see multiple MAME windows/processes, the bridge attempts to prune extras and keep the one actually connected to the TCP session
- Logs (quiet mode):
  - /tmp/mame-bridge-socat.log (bridge)
  - /tmp/mame-bridge-mame.log (MAME stdout/stderr, when auto-started)
- Volume in rc2014.sh is set low by default (-volume 1); raise to -volume 10 if audio seems missing

Manual stop (if needed)
- Graceful:
  - pkill -f "minicom .*(/tmp/mame-tty|/tmp/rc2014-tty)" || true
  - pkill -f "socat .*mame-tty" || true
  - pkill -f '(^|/)mame(\s|$)' || true
- Force (if stragglers remain):
  - pkill -9 -f '(^|/)mame(\s|$)' || true
  - pkill -9 -f socat || true
  - pkill -9 -f minicom || true
  - rm -f /tmp/mame-tty /tmp/rc2014-tty || true
  - rmdir /tmp/mame-bridge-*.lock 2>/dev/null || true

What to check if something fails
- Is rc2014.sh present and executable in the repo root?
- Does lsof show a listener on TCP:1234?
- Does /tmp/mame-tty (or your chosen PTY) exist after starting the bridge?
- Are the RomWBW assets present at the paths configured in rc2014.sh?

End of runbook.

