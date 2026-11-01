# Setting up the Rabbit Ears Raspberry Pi

About 45 minutes, most of it waiting. You need:
- your laptop with an SD card slot (or a USB SD card reader)
- the Pi's SD card, power supply and HDMI cable
- a USB keyboard and mouse for setup (afterwards your remote is enough)
- your YouTube API key and GitHub token (from your password manager)

---

## Step 1: Upload the latest Rabbit Ears files to GitHub

On github.com, open **weisser998-oss/rabbit-ears** → **Add file → Upload files**, drag in these, then **Commit changes**:

- `index.html`
- `install-pi.sh`
- `rabbit-ears-pi.py`
- `README.md` and `PI-SETUP.md`

Wait for the green check on the **Actions** tab, about a minute.

## Step 2: Erase the SD card and install Raspberry Pi OS

Installing erases the card automatically. Everything on it will be gone, so copy off anything you want to keep first.

1. On your laptop, download and install **Raspberry Pi Imager** from **raspberrypi.com/software**.
2. Put the Pi's SD card into your laptop.
3. Open Imager and choose:
   - **Device:** Raspberry Pi 4
   - **Operating system:** Raspberry Pi OS (64-bit). Use the main one *with desktop*, not "Lite".
   - **Storage:** your SD card. Check the size matches, so you don't pick your laptop's drive.
4. Click **Next**. When asked to apply OS customisation settings, click **Edit settings**:
   - **General** tab:
     - Hostname: `raspberrypi`
     - Username and password: pick a simple username like `tv` and a password you'll remember (save it in your password manager)
     - Wireless LAN: your Wi-Fi name and password, and your country
     - Locale: your time zone and keyboard layout
   - **Services** tab: tick **Enable SSH** → *Use password authentication*.
   - Click **Save**, then **Yes**.
5. Imager warns that all data on the card will be erased. Click **Yes**. Writing and checking takes 5–15 minutes.
6. When it says you can remove the card, take it out.

*If Imager won't write to the card,* go to **Operating system → Misc utility images → Erase**, run that on the card first, then start step 3 again.

## Step 3: First start-up

1. Put the SD card in the Pi. Connect the HDMI cable to your TV, plug in the keyboard and mouse, then plug in the power.
2. Wait. The first start can take a few minutes and may restart once by itself.
3. When you see the desktop, if it offers updates, let it install them. If the update tool asks to restart, restart.

## Step 4: Pair your remote (Bluetooth remotes only)

- **USB remote** (it came with a small USB plug): just plug the plug into the Pi. Skip the rest of this step.
- **Bluetooth remote:** click the **Bluetooth** icon at the top right of the screen → **Add Device**. Put the remote in pairing mode (see its instructions) and pick it from the list.

## Step 5: Install Rabbit Ears

1. Open **Terminal** (the black screen icon in the top bar).
2. Type this exactly, then press Enter:
   ```
   curl -fsSL https://weisser998-oss.github.io/rabbit-ears/install-pi.sh | bash
   ```
3. Enter your Pi password if asked. Nothing appears on screen while you type it; that's normal.
4. Answer its questions:
   - **YouTube API key:** paste it (right-click → Paste, or Ctrl+Shift+V)
   - **GitHub token:** paste it. This lets the Pi share its list of video files with your phone.
   - **Share the video folder on your Wi-Fi?** Press Enter for yes, then choose a password for the shared folder (twice).
5. Wait for **Done!**. Leave the Terminal open for now.

## Step 6: Allow the Pi to use your API key

On your laptop or phone:

1. Go to **console.cloud.google.com** → **APIs & Services → Credentials**, and click your API key.
2. Under **Website restrictions**, click **Add**, type `http://localhost:8090/*`, and click **Done**.
3. Your GitHub address should still be in the list too. Click **Save**.

## Step 7 (optional): YouTube Premium on the Pi

Only if you have YouTube Premium or a free trial. Rabbit Ears uses its own browser profile on the Pi, so you sign in to YouTube inside that profile once. In the Terminal:

```
"$(command -v chromium-browser || command -v chromium)" --user-data-dir="$HOME/.rabbit-ears/browser" https://www.youtube.com
```

Sign in to YouTube in the window that opens, then close it.

## Step 8 (optional): Remote access with Raspberry Pi Connect

This lets you see the Pi's screen or use its Terminal from your laptop or phone, so you won't need the keyboard again:

```
sudo apt install -y rpi-connect && rpi-connect on && rpi-connect signin
```

Open the link it shows and sign in with a free Raspberry Pi ID. Afterwards, find the Pi at **connect.raspberrypi.com**.

## Step 9: Start watching

In the Terminal:
```
sudo reboot
```

The Pi restarts straight into Rabbit Ears, full screen. Your channels come from your lineup on GitHub. You can unplug the keyboard and mouse now.

**Remote:** ▲/▼ change channel · **OK** opens the guide (▲/▼ to pick a channel, **OK** to tune) · **Back** closes it.

---

## Adding your own videos from your iPhone

1. Open the **Files** app → tap **⋯** (top right) → **Connect to Server**.
2. Type `smb://raspberrypi.local` and tap **Connect**.
3. Choose **Registered User**. Name: your Pi username (like `tv`). Password: the shared-folder password from step 5.
4. Open **RabbitEars**. Make a folder for each show, like `Cartoons`, and copy videos into it.
5. On your phone, in Rabbit Ears → **Settings**, add `local:Cartoons` to a channel (or tap **+ Cartoons** under the links) and **Save**. The Pi picks it up within 15 minutes, or on its next restart.

From a Mac: Finder → **Go → Connect to Server** → `smb://raspberrypi.local`. From Windows: File Explorer address bar → `\\raspberrypi.local\RabbitEars`.

## If something goes wrong

- **Rabbit Ears doesn't appear after the restart:** plug in a keyboard, open Terminal, and run `sudo systemctl status rabbit-ears`. Send me a photo of the screen.
- **"Your API key doesn't allow this website":** step 6 wasn't saved, or hasn't taken effect yet. Wait 5 minutes.
- **Getting back to the desktop:** press **Alt+F4** on a keyboard. Restart the Pi to go back into Rabbit Ears.
- **The phone can't find `raspberrypi.local`:** make sure the phone is on the same Wi-Fi, not cellular data or a VPN.
