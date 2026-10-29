#!/bin/bash
# Rabbit Ears installer for Raspberry Pi (Raspberry Pi OS with desktop).
# Run it from the Pi's Terminal:
#   curl -fsSL https://weisser998-oss.github.io/rabbit-ears/install-pi.sh | bash
# Running it again updates the helper and lets you change the keys.
set -e

SITE="${1:-https://weisser998-oss.github.io/rabbit-ears/}"
SITE="${SITE%/}/"
DIR="$HOME/.rabbit-ears"
PORT=8090

say() { printf '\n\033[1;32m==> %s\033[0m\n' "$1"; }
ask() { local reply; read -r -p "$1" reply </dev/tty; printf '%s' "$reply"; }

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user, not with sudo. It asks for your password when it needs it."
  exit 1
fi

say "Installing ffmpeg (for video lengths and converting to MP4)"
sudo apt-get update -qq
sudo apt-get install -y -qq ffmpeg python3 curl

CHROMIUM="$(command -v chromium-browser || command -v chromium || true)"
if [ -z "$CHROMIUM" ]; then
  sudo apt-get install -y -qq chromium-browser || sudo apt-get install -y -qq chromium
  CHROMIUM="$(command -v chromium-browser || command -v chromium)"
fi

say "Downloading the Rabbit Ears helper"
mkdir -p "$DIR" "$HOME/Videos/RabbitEars"
curl -fsSL "${SITE}rabbit-ears-pi.py" -o "$DIR/rabbit-ears-pi.py"

say "Settings"
OLD_KEY="$(python3 -c "import json;print(json.load(open('$DIR/config.json')).get('apiKey',''))" 2>/dev/null || true)"
OLD_TOKEN="$(python3 -c "import json;print(json.load(open('$DIR/config.json')).get('ghToken',''))" 2>/dev/null || true)"
echo "Paste your YouTube API key (the same one your phone uses)."
[ -n "$OLD_KEY" ] && echo "Press Enter to keep the one you already set."
KEY="$(ask 'YouTube API key: ')"; KEY="${KEY:-$OLD_KEY}"
echo
echo "Optional: paste a GitHub token so the Pi can share its list of video files with your phone."
echo "Press Enter to skip$( [ -n "$OLD_TOKEN" ] && echo ' (keeps the one you already set)')."
TOKEN="$(ask 'GitHub token: ')"; TOKEN="${TOKEN:-$OLD_TOKEN}"

KEY="$KEY" TOKEN="$TOKEN" SITE="$SITE" PORT="$PORT" python3 - <<'PY'
import json, os
from pathlib import Path
p = Path.home() / ".rabbit-ears" / "config.json"
p.write_text(json.dumps({"site": os.environ["SITE"], "port": int(os.environ["PORT"]), "apiKey": os.environ["KEY"],
                         "ghToken": os.environ["TOKEN"], "preload": "off"}, indent=2))
p.chmod(0o600)
PY

say "Starting the helper now and on every boot"
sudo tee /etc/systemd/system/rabbit-ears.service >/dev/null <<EOF
[Unit]
Description=Rabbit Ears helper
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
Environment=HOME=$HOME USER=$USER
ExecStart=/usr/bin/python3 $DIR/rabbit-ears-pi.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now rabbit-ears.service
sudo systemctl restart rabbit-ears.service

say "Opening Rabbit Ears full screen when the Pi starts"
cat > "$DIR/kiosk.sh" <<EOF
#!/bin/bash
# Only one copy, even if more than one autostart method fires.
exec 9>"$DIR/kiosk.lock"
flock -n 9 || exit 0
for i in \$(seq 1 30); do curl -fs "http://localhost:$PORT/api/config" >/dev/null && break; sleep 1; done
exec "$CHROMIUM" --kiosk --noerrdialogs --disable-infobars --no-first-run --disable-session-crashed-bubble \\
  --autoplay-policy=no-user-gesture-required --disable-features=Translate --overscroll-history-navigation=0 \\
  --check-for-update-interval=31536000 --password-store=basic --user-data-dir="$DIR/browser" \\
  "http://localhost:$PORT/"
EOF
chmod +x "$DIR/kiosk.sh"

mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/rabbit-ears.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Rabbit Ears
Exec=$DIR/kiosk.sh
X-GNOME-Autostart-enabled=true
EOF
# Newer Raspberry Pi OS desktops (labwc) also read their own autostart file.
mkdir -p "$HOME/.config/labwc"
touch "$HOME/.config/labwc/autostart"
grep -q "rabbit-ears/kiosk.sh" "$HOME/.config/labwc/autostart" || echo "$DIR/kiosk.sh &" >> "$HOME/.config/labwc/autostart"

say "Keeping the screen on"
sudo raspi-config nonint do_blanking 1 2>/dev/null || true

sleep 2
if curl -fs "http://localhost:$PORT/api/config" >/dev/null; then
  say "Done!"
else
  echo "The helper didn't start. Check it with:  sudo systemctl status rabbit-ears"
  exit 1
fi
cat <<EOF

One more step on your computer or phone:
  In Google Cloud (APIs & Services -> Credentials -> your API key -> Websites), add:
      http://localhost:$PORT/*
  next to your GitHub address, then Save.

Put videos in  ~/Videos/RabbitEars  (one folder per show), or in a folder called
RabbitEars on a USB drive. Then add a line like  local:Folder name  to a channel.

Restart the Pi to start watching:  sudo reboot
To get back to the desktop while it's running, press Alt+F4 on a keyboard.
EOF
