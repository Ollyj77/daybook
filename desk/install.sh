#!/bin/bash
# Daybook desk installer for a Raspberry Pi (Raspberry Pi OS Lite, 64-bit).
# Run on the Pi:  curl -fsSL https://ollyj77.github.io/daybook/desk/install.sh | bash
set -euo pipefail

BASE="https://ollyj77.github.io/daybook/desk"
DIR="$HOME/daybook-desk"
CONF_DIR="$HOME/.config/daybook-desk"
USER_NAME="$(id -un)"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

say "1/6  Setting the clock to Sydney time"
sudo timedatectl set-timezone Australia/Sydney

say "2/6  Installing Chromium and Python imaging (this takes a while on a Pi Zero)"
sudo apt-get update -qq
if apt-cache show chromium >/dev/null 2>&1; then CH=chromium; else CH=chromium-browser; fi
sudo apt-get install -y -qq "$CH" python3-pil fonts-dejavu-core >/dev/null

# Chromium needs more than the Zero 2 W's 512 MB, so make sure there is some swap.
SWAP_MB=$(free -m | awk '/^Swap:/ {print $2}')
if [ "${SWAP_MB:-0}" -lt 400 ] && [ -f /etc/dphys-swapfile ]; then
  sudo sed -i 's/^#\?CONF_SWAPSIZE=.*/CONF_SWAPSIZE=512/' /etc/dphys-swapfile
  sudo systemctl restart dphys-swapfile || true
fi

say "3/6  Downloading the desk scripts"
mkdir -p "$DIR/www" "$CONF_DIR"
curl -fsSL "$BASE/render.sh"    -o "$DIR/render.sh"
curl -fsSL "$BASE/convert.py"   -o "$DIR/convert.py"
curl -fsSL "$BASE/viewer.html"  -o "$DIR/www/index.html"
chmod +x "$DIR/render.sh"

say "4/6  Access key"
if [ -f "$CONF_DIR/config" ] && grep -q '^DAYBOOK_KEY=.' "$CONF_DIR/config"; then
  echo "A key is already saved. Keeping it. (Delete $CONF_DIR/config and re-run to replace it.)"
else
  echo "Paste the read-only GitHub key for daybook-data (starts with github_pat_)."
  echo "Nothing will show while you paste. Press Enter when done."
  read -rs KEY < /dev/tty; echo
  case "$KEY" in github_pat_*|ghp_*) ;; *) echo "That doesn't look like a GitHub key. Re-run the installer to try again."; exit 1;; esac
  umask 077
  cat > "$CONF_DIR/config" <<EOF
DAYBOOK_KEY=$KEY
DAYBOOK_REPO=Ollyj77/daybook-data
# No renders between these hours (24h clock); the last frame stays up.
QUIET_FROM=23
QUIET_TO=6
EOF
  umask 022
fi

say "5/6  Scheduling renders every 5 minutes and starting the preview page"
sudo tee /etc/systemd/system/daybook-desk.service >/dev/null <<EOF
[Unit]
Description=Daybook desk render
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=$USER_NAME
ExecStart=$DIR/render.sh
Nice=10
EOF
sudo tee /etc/systemd/system/daybook-desk.timer >/dev/null <<EOF
[Unit]
Description=Render the Daybook desk view every 5 minutes

[Timer]
OnBootSec=1min
OnCalendar=*:0/5
AccuracySec=30s

[Install]
WantedBy=timers.target
EOF
sudo tee /etc/systemd/system/daybook-desk-web.service >/dev/null <<EOF
[Unit]
Description=Daybook desk preview page
After=network-online.target

[Service]
User=$USER_NAME
WorkingDirectory=$DIR/www
ExecStart=/usr/bin/python3 -m http.server 8080
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now daybook-desk.timer daybook-desk-web.service >/dev/null

say "6/6  First render (up to a couple of minutes)"
FORCE=1 "$DIR/render.sh" || true
tail -n 1 "$DIR/log.txt" 2>/dev/null || true

say "Done."
echo "Open this on your phone or computer (same Wi-Fi):  http://$(hostname).local:8080"
echo "Render by hand any time:  FORCE=1 ~/daybook-desk/render.sh"
