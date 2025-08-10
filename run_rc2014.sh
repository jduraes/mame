#!/usr/bin/env bash
# socat_mame_bridge.sh
# Bridge a MAME null_modem TCP listener to a local PTY and launch Minicom.
#
# Usage:
#   ./scripts/socat_mame_bridge.sh [PORT] [PTY_LINK] [BAUD] [MINICOM_EXTRA_ARGS...]
#   ./scripts/socat_mame_bridge.sh --listen [PORT] [PTY_LINK] [BAUD] [MINICOM_EXTRA_ARGS...]
#   ./scripts/socat_mame_bridge.sh [--rc-script /path/to/rc2014.sh] [PORT] [PTY_LINK] [BAUD] [MINICOM_EXTRA_ARGS...]
#
# Defaults:
#   PORT     = 1234
#   PTY_LINK = /tmp/mame-tty
#   BAUD     = 115200
#
# Examples:
#   # Connect to a listener at 127.0.0.1:1234 (MAME listening)
#   ./scripts/socat_mame_bridge.sh
#   ./scripts/socat_mame_bridge.sh 1234 /tmp/rc2014-tty 57600
#   ./scripts/socat_mame_bridge.sh 1234 /tmp/rc2014-tty 115200 -7   # pass extra args to minicom
#   # Listen for an outgoing connection from MAME (MAME connects)
#   ./scripts/socat_mame_bridge.sh --listen 1234 /tmp/rc2014-tty 115200
#   # Auto-restart MAME (kill, then run rc2014.sh) if not listening when connecting:
#   ./scripts/socat_mame_bridge.sh --rc-script /path/to/rc2014.sh 1234 /tmp/rc2014-tty 115200
#
# Notes:
# - MAME is the TCP listener per your rc2014 setup; this script connects to it
#   and exposes a local PTY at PTY_LINK.
# - The bridge auto-reconnects if MAME restarts.
# - Ensure lrzsz is installed for X/Y/ZMODEM: `brew install lrzsz`

set -uo pipefail

MODE="connect"  # default to connect (MAME listens, socat connects)
# Auto-detect rc script if present in cwd
RC_SCRIPT=""
if [ -x "./rc2014.sh" ]; then
  RC_SCRIPT="./rc2014.sh"
fi
FORCE_RESTART="0"
SINGLE_INSTANCE="1"
QUIET="1"  # default to quiet; only log to files
# Parse leading flags
while [ $# -gt 0 ]; do
  case "${1}" in
    --listen)
      MODE="listen"; shift ;;
    --rc-script)
      RC_SCRIPT="${2-}"; shift 2 ;;
    --force-restart)
      FORCE_RESTART="1"; shift ;;
    --allow-multiple)
      SINGLE_INSTANCE="0"; shift ;;
    --verbose)
      QUIET="0"; shift ;;
    --)
      shift; break ;;
    --*)
      [ "${QUIET}" = "0" ] && echo "Unknown option: ${1}" 1>&2; exit 2 ;;
    *)
      break ;;
  esac
done

# Pre-flight cleanup: kill lingering processes and stale PTY/locks
preflight_cleanup() {
  # Best-effort terminate minicom using our PTY
  pkill -f "minicom .*${PTY_LINK}" 2>/dev/null || true
  sleep 0.2
  pkill -9 -f "minicom .*${PTY_LINK}" 2>/dev/null || true

  # Terminate socat bridges referencing our PTY or port
  pkill -f "socat .*${PTY_LINK}" 2>/dev/null || true
  pkill -f "socat .*tcp-listen:${PORT}" 2>/dev/null || true
  pkill -f "socat .*tcp:127\.0\.0\.1:${PORT}" 2>/dev/null || true
  sleep 0.2
  pkill -9 -f "socat .*${PTY_LINK}" 2>/dev/null || true
  pkill -9 -f "socat .*tcp-listen:${PORT}" 2>/dev/null || true
  pkill -9 -f "socat .*tcp:127\.0\.0\.1:${PORT}" 2>/dev/null || true

  # Terminate any running mame instances (we will start a fresh one later)
  pkill -f "(^|/)mame(\s|$)" 2>/dev/null || true
  sleep 0.2
  # Force kill leftovers
  pgrep -f "(^|/)mame(\s|$)" >/dev/null 2>&1 && pkill -9 -f "(^|/)mame(\s|$)" 2>/dev/null || true

  # Remove stale PTY link
  [ -e "${PTY_LINK}" ] && rm -f "${PTY_LINK}" || true

  # Remove stale lock for this port
  [ -d "/tmp/mame-bridge-${PORT}.lock" ] && rmdir "/tmp/mame-bridge-${PORT}.lock" 2>/dev/null || true
}

PORT="${1:-1234}"
PTY_LINK="${2:-/tmp/mame-tty}"
BAUD="${3:-115200}"
shift $(( $# > 0 ? 1 : 0 ))
shift $(( $# > 0 ? 1 : 0 ))
shift $(( $# > 0 ? 1 : 0 ))
# Collect any extra args for minicom
MINICOM_EXTRA_ARGS=("$@")

# Execute pre-flight cleanup now that PORT/PTY_LINK are known
preflight_cleanup

# Single-instance lock per port to avoid multiple concurrent bridges starting MAME repeatedly
LOCK_DIR="/tmp/mame-bridge-${PORT}.lock"
if [ "${SINGLE_INSTANCE}" = "1" ]; then
  if mkdir "${LOCK_DIR}" 2>/dev/null; then
    : # acquired
  else
    echo "Another bridge instance for port ${PORT} appears to be running (lock ${LOCK_DIR})." 1>&2
    echo "Use --allow-multiple to bypass, or stop the other instance first." 1>&2
    exit 3
  fi
fi

if ! command -v socat > /dev/null 2>&1; then
  echo "Error: socat is not installed. On macOS: brew install socat" >&2
  exit 1
fi
if ! command -v minicom > /dev/null 2>&1; then
  echo "Warning: minicom is not installed. On macOS: brew install minicom" >&2
fi

# Clean up the PTY link and background socat on exit
SOCAT_PID=""
# Track any MAME PIDs we detected/started so we can terminate them when Minicom exits
MAME_PIDS_ON_PORT=""
cleanup() {
  # Kill socat bridge
  if [ -n "${SOCAT_PID}" ] && kill -0 "${SOCAT_PID}" 2>/dev/null; then
    kill "${SOCAT_PID}" 2>/dev/null || true
    wait "${SOCAT_PID}" 2>/dev/null || true
  fi
  # Tear down PTY symlink
  if [ -L "${PTY_LINK}" ] || [ -e "${PTY_LINK}" ]; then
    rm -f "${PTY_LINK}" || true
  fi
  # If we recorded listener PIDs, terminate them; otherwise, do not guess to avoid killing wrong processes
  if [ -n "${MAME_PIDS_ON_PORT}" ]; then
    [ "${QUIET}" = "0" ] && echo "Shutting down MAME (PIDs: ${MAME_PIDS_ON_PORT})..."
    for p in ${MAME_PIDS_ON_PORT}; do
      kill "${p}" 2>/dev/null || true
    done
    sleep 0.5
    # Force kill if still running
    for p in ${MAME_PIDS_ON_PORT}; do
      if kill -0 "${p}" 2>/dev/null; then
        kill -9 "${p}" 2>/dev/null || true
      fi
    done
  fi
  # Release lock
  if [ -n "${LOCK_DIR-}" ] && [ -d "${LOCK_DIR}" ]; then
    rmdir "${LOCK_DIR}" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

if [ "${MODE}" = "listen" ]; then
  [ "${QUIET}" = "0" ] && echo "Creating PTY bridge at ${PTY_LINK} <- tcp-listen:${PORT} (waiting for peer)"
else
  [ "${QUIET}" = "0" ] && echo "Creating PTY bridge at ${PTY_LINK} -> tcp:127.0.0.1:${PORT} (connecting to listener)"
  # Pre-flight: ensure exactly one MAME is running and listening, auto-fix if needed
  ensure_mame_listener() {
    local listen_pid all_pids count
    listen_pid=$(lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN -t -a -c mame 2>/dev/null || true)
    all_pids=$(pgrep -f "(^|/)mame(\\s|$)" || true)
    if [ -n "${all_pids}" ]; then
      count=$(echo "${all_pids}" | wc -l | tr -d ' ')
      if [ "${count}" -gt 1 ]; then
        [ "${QUIET}" = "0" ] && echo "Detected ${count} MAME processes; pruning extras..."
        if [ -n "${listen_pid}" ]; then
          for p in ${all_pids}; do
            if [ "${p}" != "${listen_pid}" ]; then
              kill "${p}" 2>/dev/null || true
            fi
          done
        else
          [ "${QUIET}" = "0" ] && echo "No listener among running MAMEs; killing all to start cleanly..."
          pkill -f "(^|/)mame(\\s|$)" 2>/dev/null || true
        fi
        sleep 1
      fi
    fi
    if ! lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
      if pgrep -f "(^|/)mame(\\s|$)" >/dev/null 2>&1; then
        [ "${QUIET}" = "0" ] && echo "MAME running but not listening; waiting up to 10s..."
        for _t in {1..20}; do
          if lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
            break
          fi
          sleep 0.5
        done
      fi
    fi
    if ! lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
      if [ -n "${RC_SCRIPT}" ] && [ -x "${RC_SCRIPT}" ]; then
        [ "${QUIET}" = "0" ] && echo "Starting MAME via ${RC_SCRIPT}..."
        nohup "${RC_SCRIPT}" >> /tmp/mame-bridge-mame.log 2>&1 &
        for _t in {1..40}; do
          if lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
            break
          fi
          sleep 0.5
        done
      else
        [ "${QUIET}" = "0" ] && echo "RC script not available or not executable; cannot auto-start MAME." 1>&2
      fi
    fi
    if lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
      # Save PIDs of the listener(s) on this port for cleanup later
      MAME_PIDS_ON_PORT=$(lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN -t -a -c mame 2>/dev/null || true)
      [ "${QUIET}" = "0" ] && echo "Detected listener on port ${PORT}. Proceeding."
    else
      [ "${QUIET}" = "0" ] && echo "Warning: MAME did not start listening on ${PORT}. Will rely on socat auto-retry." 1>&2
    fi
  }
  ensure_mame_listener
fi

# Start a reconnecting socat bridge in the background (quiet by default)
(
  while true; do
    if [ "${MODE}" = "listen" ]; then
      socat \
        pty,raw,echo=0,link="${PTY_LINK}",mode=666 \
        tcp-listen:"${PORT}",reuseaddr 2>>/tmp/mame-bridge-socat.log || true
    else
      socat \
        pty,raw,echo=0,link="${PTY_LINK}",mode=666 \
        tcp:127.0.0.1:"${PORT}" 2>>/tmp/mame-bridge-socat.log || true
    fi
    [ "${QUIET}" = "0" ] && echo "socat disconnected; retrying in 2s..." 1>&2
    sleep 2
  done
) &
SOCAT_PID=$!

# If we are listening (MAME connects), start MAME now
if [ "${MODE}" = "listen" ] && [ -n "${RC_SCRIPT}" ] && [ -x "${RC_SCRIPT}" ]; then
  # Wait for socat to be in LISTEN state on the port to avoid race
  for _t in {1..50}; do
    if lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN >/dev/null 2>/dev/null; then
      break
    fi
    sleep 0.1
  done
  # If a MAME is already running, leave it; otherwise start one
  if ! pgrep -f "(^|/)mame(\s|$)" > /dev/null 2>/dev/null; then
    nohup "${RC_SCRIPT}" >> /tmp/mame-bridge-mame.log 2>>/tmp/mame-bridge-mame.log &
  fi
fi

# Wait for the PTY to appear
for _i in {1..50}; do
  if [ -e "${PTY_LINK}" ]; then
    break
  fi
  sleep 0.1
done

if [ ! -e "${PTY_LINK}" ]; then
  echo "Error: PTY ${PTY_LINK} was not created." 1>&2
  exit 1
fi

# After MAME connects, prune any extra MAME instances to avoid duplicates
prune_extra_mame() {
  # Get the PID of MAME with an established connection to our listener
  local established_pid
  established_pid=$(lsof -nP -iTCP:"${PORT}" -sTCP:ESTABLISHED -t -a -c mame 2>/dev/null | head -n1 || true)
  local all_mame
  all_mame=$(pgrep -f "(^|/)mame(\s|$)" || true)
  if [ -n "${all_mame}" ]; then
    for p in ${all_mame}; do
      if [ -n "${established_pid}" ] && [ "${p}" = "${established_pid}" ]; then
        continue
      fi
      # Keep only the established one; kill the rest
      kill "${p}" 2>/dev/null || true
    done
    sleep 0.3
    # Force kill stragglers
    for p in ${all_mame}; do
      if [ -n "${established_pid}" ] && [ "${p}" = "${established_pid}" ]; then
        continue
      fi
      kill -0 "${p}" 2>/dev/null && kill -9 "${p}" 2>/dev/null || true
    done
    # Record the established PID for cleanup on exit
    if [ -n "${established_pid}" ]; then
      MAME_PIDS_ON_PORT="${established_pid}"
    fi
  fi
}

# Give MAME a moment to connect, then prune extras
for _i in {1..50}; do
  if lsof -nP -iTCP:"${PORT}" -sTCP:ESTABLISHED >/dev/null 2>/dev/null; then
    prune_extra_mame
    break
  fi
  sleep 0.1
done

[ "${QUIET}" = "0" ] && echo "Launching Minicom on ${PTY_LINK} at ${BAUD} baud (foreground)..."
# Build command array
MINICOM_CMD=(minicom -o -D "${PTY_LINK}" -b "${BAUD}")
if [ ${#MINICOM_EXTRA_ARGS[@]} -gt 0 ]; then
  MINICOM_CMD+=("${MINICOM_EXTRA_ARGS[@]}")
fi
# Run minicom in the foreground so the user has an interactive session
# When minicom exits, the EXIT trap will clean up socat, PTY, and any recorded MAME PIDs
"${MINICOM_CMD[@]}"
# cleanup trap will trigger on script exit
exit 0

