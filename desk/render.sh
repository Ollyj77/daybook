#!/bin/bash
# Daybook desk: render the desk view to an 800x480 black-and-white image.
# Runs every 5 minutes from a systemd timer (daybook-desk.timer). Safe to run by hand: ~/daybook-desk/render.sh
set -uo pipefail

DIR="$HOME/daybook-desk"
CONF="$HOME/.config/daybook-desk/config"
WWW="$DIR/www"
mkdir -p "$WWW"

# shellcheck source=/dev/null
source "$CONF"   # sets DAYBOOK_KEY, DAYBOOK_REPO, QUIET_FROM, QUIET_TO

# Quiet hours: leave the last image up overnight (e-ink holds it with no power).
H=$((10#$(date +%H)))
if [ "${FORCE:-0}" != "1" ] && { [ "$H" -ge "${QUIET_FROM:-23}" ] || [ "$H" -lt "${QUIET_TO:-6}" ]; }; then
  exit 0
fi

CHROME="$(command -v chromium || command -v chromium-browser)"
PROFILE="$(mktemp -d)"
RAW="$DIR/raw.png"
trap 'rm -rf "$PROFILE"' EXIT

# The key goes after "#", so it is never sent to GitHub Pages; the page only uses it to read daybook-data.
URL="https://ollyj77.github.io/daybook/?desk#key=${DAYBOOK_KEY}&repo=${DAYBOOK_REPO:-Ollyj77/daybook-data}"

rm -f "$RAW"
timeout 150 "$CHROME" --headless --disable-gpu --disable-dev-shm-usage --no-first-run --disable-extensions \
  --mute-audio --hide-scrollbars --force-device-scale-factor=1 --window-size=800,600 \
  --user-data-dir="$PROFILE" --virtual-time-budget=25000 \
  --screenshot="$RAW" "$URL" >/dev/null 2>&1

if [ ! -s "$RAW" ]; then
  echo "$(date '+%F %T') render failed (Chromium produced no image)" >> "$DIR/log.txt"
  exit 1
fi

python3 "$DIR/convert.py" "$RAW" "$WWW" >> "$DIR/log.txt" 2>&1
tail -n 200 "$DIR/log.txt" > "$DIR/log.tmp" && mv "$DIR/log.tmp" "$DIR/log.txt"
