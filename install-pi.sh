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
sudo apt-get install -y -qq wlr-randr 2>/dev/null || true

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
OLD_RES="$(python3 -c "import json;print(json.load(open('$DIR/config.json')).get('resolution',''))" 2>/dev/null || true)"
echo "Paste your YouTube API key (the same one your phone uses)."
[ -n "$OLD_KEY" ] && echo "Press Enter to keep the one you already set."
KEY="$(ask 'YouTube API key: ')"; KEY="${KEY:-$OLD_KEY}"
echo
echo "Optional: paste a GitHub token so the Pi can share its list of video files with your phone."
echo "Press Enter to skip$( [ -n "$OLD_TOKEN" ] && echo ' (keeps the one you already set)')."
TOKEN="$(ask 'GitHub token: ')"; TOKEN="${TOKEN:-$OLD_TOKEN}"
echo
echo "Screen resolution. A lower one makes everything bigger, and suits small screens and TVs"
echo "connected through an HDMI-to-AV adaptor. Try 720x480 or 1280x720."
echo "Type 'auto' to let the Pi choose. Press Enter to keep: ${OLD_RES:-auto}"
RES="$(ask 'Resolution: ')"; RES="${RES:-$OLD_RES}"; [ "$RES" = "auto" ] && RES=""

KEY="$KEY" TOKEN="$TOKEN" RES="$RES" SITE="$SITE" PORT="$PORT" python3 - <<'PY'
import json, os
from pathlib import Path
p = Path.home() / ".rabbit-ears" / "config.json"
p.write_text(json.dumps({"site": os.environ["SITE"], "port": int(os.environ["PORT"]), "apiKey": os.environ["KEY"],
                         "ghToken": os.environ["TOKEN"], "preload": "off", "resolution": os.environ["RES"]}, indent=2))
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
# Screen resolution from config.json (empty = leave it to the Pi).
RES="\$(python3 -c "import json;print(json.load(open('$DIR/config.json')).get('resolution',''))" 2>/dev/null)"
if [ -n "\$RES" ]; then
  if [ -n "\$WAYLAND_DISPLAY" ] && command -v wlr-randr >/dev/null; then
    OUT="\$(wlr-randr | awk '/^[^ ]/{print \$1; exit}')"
    wlr-randr --output "\$OUT" --mode "\$RES" 2>/dev/null || wlr-randr --output "\$OUT" --custom-mode "\$RES"
  elif command -v xrandr >/dev/null; then
    xrandr --output "\$(xrandr | awk '/ connected/{print \$1; exit}')" --mode "\$RES"
  fi
  sleep 1
fi
# Full volume: the TV's own buttons control loudness.
wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0 2>/dev/null || true
wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null || true
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

echo
if grep -qs "^\[RabbitEars\]" /etc/samba/smb.conf; then
  echo "The video folder is already shared on your Wi-Fi."
  SHARE=n; SHARED=1
else
  SHARE="$(ask 'Share the video folder on your Wi-Fi, so your phone and laptop can add videos? (Y/n): ')"
fi
if [[ ! "$SHARE" =~ ^[Nn] ]]; then
  say "Sharing Videos/RabbitEars on your Wi-Fi"
  sudo apt-get install -y -qq samba
  if ! grep -q "^\[RabbitEars\]" /etc/samba/smb.conf; then
    sudo tee -a /etc/samba/smb.conf >/dev/null <<EOF

[RabbitEars]
   path = $HOME/Videos/RabbitEars
   browseable = yes
   read only = no
   valid users = $USER
   force user = $USER
   create mask = 0644
   directory mask = 0755
EOF
  fi
  while true; do
    read -r -s -p "Choose a password for the shared folder (your phone will ask for it): " PW1 </dev/tty; echo
    read -r -s -p "Type it again: " PW2 </dev/tty; echo
    [ -n "$PW1" ] && [ "$PW1" = "$PW2" ] && break
    echo "Those didn't match (or were empty). Try again."
  done
  printf '%s\n%s\n' "$PW1" "$PW1" | sudo smbpasswd -s -a "$USER" >/dev/null
  sudo systemctl restart smbd
  SHARED=1
fi

echo
HIDE="$(ask 'Hide the mouse pointer on the Pi? (Y/n): ')"
if [[ ! "$HIDE" =~ ^[Nn] ]]; then
  say "Hiding the mouse pointer"
  # A cursor theme whose pointers are all a single transparent pixel.
  python3 - <<'PY'
import struct
from pathlib import Path
d = Path.home() / ".local/share/icons/rabbit-ears-blank"
(d / "cursors").mkdir(parents=True, exist_ok=True)
(d / "index.theme").write_text("[Icon Theme]\nName=rabbit-ears-blank\nComment=Invisible pointer for Rabbit Ears\n")
IMG = 0xfffd0002
sizes = [24, 32, 48, 64]
header = 16 + 12 * len(sizes)
chunks, toc, pos = b"", b"", header
for s in sizes:
    chunk = struct.pack("<9I", 36, IMG, s, 1, 1, 1, 0, 0, 0) + struct.pack("<I", 0)  # 1x1, fully transparent
    toc += struct.pack("<3I", IMG, s, pos)
    chunks += chunk; pos += len(chunk)
data = b"Xcur" + struct.pack("<3I", 16, 0x10000, len(sizes)) + toc + chunks
names = ("left_ptr default arrow top_left_arrow pointer hand1 hand2 pointing_hand text xterm ibeam watch wait progress "
         "left_ptr_watch crosshair cross move grabbing grab all-scroll not-allowed col-resize row-resize "
         "n-resize s-resize e-resize w-resize ne-resize nw-resize se-resize sw-resize ew-resize ns-resize "
         "nesw-resize nwse-resize sb_h_double_arrow sb_v_double_arrow fleur question_arrow help context-menu").split()
for n in names:
    (d / "cursors" / n).write_bytes(data)
PY
  mkdir -p "$HOME/.config/labwc"
  touch "$HOME/.config/labwc/environment"
  sed -i '/^XCURSOR_THEME=/d;/^XCURSOR_SIZE=/d' "$HOME/.config/labwc/environment"
  printf 'XCURSOR_THEME=rabbit-ears-blank\nXCURSOR_SIZE=24\n' >> "$HOME/.config/labwc/environment"
  if [ -f "$HOME/.config/wayfire.ini" ] && ! grep -q "rabbit-ears-blank" "$HOME/.config/wayfire.ini"; then
    printf '\n[input]\ncursor_theme = rabbit-ears-blank\ncursor_size = 24\n' >> "$HOME/.config/wayfire.ini"
  fi
  HIDDEN=1
else
  # Bring the normal pointer back.
  sed -i '/^XCURSOR_THEME=rabbit-ears-blank/d;/^XCURSOR_SIZE=24$/d' "$HOME/.config/labwc/environment" 2>/dev/null || true
  sed -i '/cursor_theme = rabbit-ears-blank/d' "$HOME/.config/wayfire.ini" 2>/dev/null || true
fi

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

$( [ -n "$SHARED" ] && printf 'To add videos from your phone or laptop over Wi-Fi, connect to\n    smb://%s.local   (user: %s, and the password you just chose)\nand open the RabbitEars folder.\n' "$(hostname)" "$USER" )

Restart the Pi to start watching:  sudo reboot
To get back to the desktop while it's running, press Alt+F4 on a keyboard.
EOF
