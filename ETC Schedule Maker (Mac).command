#!/bin/bash
# ETC Schedule Maker (Emerald Triangle Cannabis) launcher for macOS.
# On launch: check GitHub for a newer app.html, download if found, then open it.
# Offline / unreachable / bad download -> silently run the copy we already have.
# This mirrors the Windows "ETC Schedule Maker.vbs" launcher.

UPDATE_BASE="https://raw.githubusercontent.com/madisonhypes/etc-schedule-maker/main"
MIN_SIZE=40000   # bytes; reject truncated / error-page downloads

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLED="$SCRIPT_DIR/app.html"

# working copy lives in Application Support so updates never touch the install folder
SUPPORT="$HOME/Library/Application Support/ETCScheduleMaker"
mkdir -p "$SUPPORT"
LIVE="$SUPPORT/app.html"

# turn 1.8.1 -> a comparable number
vernum(){ echo "$1" | awk -F. '{printf "%d%03d%03d\n", $1+0, $2+0, $3+0}'; }
is_version(){ echo "$1" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; }
valid_html(){ [ -s "$1" ] && [ "$(stat -f%z "$1" 2>/dev/null || echo 0)" -ge "$MIN_SIZE" ] && grep -q "</html>" "$1"; }

bundledVer="$(tr -d '[:space:]' < "$SCRIPT_DIR/version.txt" 2>/dev/null)"; [ -z "$bundledVer" ] && bundledVer="0.0.0"
liveVer="$(tr -d '[:space:]' < "$SUPPORT/version.txt" 2>/dev/null)"; [ -z "$liveVer" ] && liveVer="0.0.0"

# 1. seed / restore the working copy from the bundled one
if ! valid_html "$LIVE" || [ "$(vernum "$bundledVer")" -gt "$(vernum "$liveVer")" ]; then
  cp "$BUNDLED" "$LIVE" 2>/dev/null && printf '%s' "$bundledVer" > "$SUPPORT/version.txt"
  liveVer="$bundledVer"
fi

# 2. check GitHub for something newer
remoteVer="$(curl -fsSL "$UPDATE_BASE/version.txt?nocache=$(date +%s)" 2>/dev/null | tr -d '[:space:]')"
if is_version "$remoteVer" && [ "$(vernum "$remoteVer")" -gt "$(vernum "$liveVer")" ]; then
  TMP="$SUPPORT/app.download"
  if curl -fsSL "$UPDATE_BASE/app.html?nocache=$(date +%s)" -o "$TMP" 2>/dev/null && valid_html "$TMP"; then
    cp "$TMP" "$LIVE" && printf '%s' "$remoteVer" > "$SUPPORT/version.txt"
  fi
  rm -f "$TMP"
fi

# 3. open whichever copy we ended up with
TARGET="$LIVE"; valid_html "$TARGET" || TARGET="$BUNDLED"
URL="file://$TARGET"; URL="$(printf '%s' "$URL" | sed 's/ /%20/g')"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
EDGE="/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"

if [ -x "$CHROME" ]; then
  "$CHROME" --app="$URL" --window-size=1440,920 >/dev/null 2>&1 &
elif [ -x "$EDGE" ]; then
  "$EDGE" --app="$URL" --window-size=1440,920 >/dev/null 2>&1 &
else
  # no Chrome/Edge found -> open in the default browser (Safari).
  open "$TARGET"
fi

exit 0
