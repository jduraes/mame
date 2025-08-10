#!/usr/bin/env bash
# Track MAME build size and archive the produced binary with timestamp metadata.
# macOS-compatible (uses stat -f and sysctl).
#
# Usage examples:
#   scripts/tools/track_build.sh -- make -j$(sysctl -n hw.ncpu) SOURCES=src/mame/rc2014.lst
#   scripts/tools/track_build.sh -- make -j$(sysctl -n hw.ncpu) SUBTARGET=rc2014 REGENIE=1
#
# Everything after the first "--" is executed as the build command.
set -euo pipefail

if [[ "$#" -lt 2 ]]; then
  echo "Usage: $0 -- <build command ...>" >&2
  exit 1
fi

# Find project root (this script may be invoked from anywhere)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Prepare artifacts directory
ART_DIR="$REPO_ROOT/build_artifacts"
mkdir -p "$ART_DIR"

# Capture VCS metadata if available
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD || echo "unknown")
  GIT_SHA=$(git rev-parse --short=12 HEAD || echo "unknown")
  GIT_STATUS=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
else
  GIT_BRANCH="nogit"
  GIT_SHA="nogit"
  GIT_STATUS=0
fi

# Timestamp
STAMP=$(date +%Y%m%d-%H%M%S)

# Build
shift  # drop the "--"
BUILD_CMD=("$@")

echo "[track_build] Running: ${BUILD_CMD[*]}" >&2
"${BUILD_CMD[@]}"

# Detect produced binary path candidates
BIN_CANDIDATES=(
  "$REPO_ROOT/mame"
  "$REPO_ROOT/mamerc2014"
  "$REPO_ROOT/build/osx_clang/bin/x64/Release/mame"
  "$REPO_ROOT/build/osx_clang/bin/x64/Release/mamerc2014"
)
BIN_PATH=""
for p in "${BIN_CANDIDATES[@]}"; do
  if [[ -x "$p" ]]; then BIN_PATH="$p"; break; fi
  if [[ -f "$p" ]]; then BIN_PATH="$p"; break; fi
done

if [[ -z "$BIN_PATH" ]]; then
  echo "[track_build] ERROR: Could not find built binary. Checked: ${BIN_CANDIDATES[*]}" >&2
  exit 2
fi

# Compute sizes
if stat -f "%z" "$BIN_PATH" >/dev/null 2>&1; then
  SIZE_BYTES=$(stat -f "%z" "$BIN_PATH")
else
  # Fallback for other platforms
  SIZE_BYTES=$(wc -c < "$BIN_PATH")
fi
SIZE_HUMAN=$(du -h "$BIN_PATH" | awk '{print $1}')

# Compose archived name and copy
BASE_NAME=$(basename "$BIN_PATH")
ARCHIVE_NAME="${BASE_NAME}-${STAMP}-${GIT_BRANCH}-${GIT_SHA}-${SIZE_BYTES}B"
cp -f "$BIN_PATH" "$ART_DIR/$ARCHIVE_NAME"

# Append CSV log
CSV="$ART_DIR/build_sizes.csv"
if [[ ! -f "$CSV" ]]; then
  echo "timestamp,branch,commit,dirty_count,binary,size_bytes,size_human,archived_to,cmd" > "$CSV"
fi
printf "%s,%s,%s,%s,%s,%s,%s,%s,\"%s\"\n" \
  "$STAMP" "$GIT_BRANCH" "$GIT_SHA" "$GIT_STATUS" "$BIN_PATH" "$SIZE_BYTES" "$SIZE_HUMAN" "$ART_DIR/$ARCHIVE_NAME" "${BUILD_CMD[*]}" \
  >> "$CSV"

echo "[track_build] Binary: $BIN_PATH" >&2
echo "[track_build] Size:   $SIZE_BYTES bytes ($SIZE_HUMAN)" >&2
echo "[track_build] Saved:  $ART_DIR/$ARCHIVE_NAME" >&2
echo "[track_build] Log:    $CSV (tail -1)" >&2

