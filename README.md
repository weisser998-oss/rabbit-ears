# Rabbit Ears

Your YouTube, broadcast like live TV. Plain static files, no server, no build step.

Files: `index.html` (the app), `manifest.webmanifest` and the three `.png` icons (for installing it on a phone home screen). Upload all of them together.

## 1. Get a YouTube API key (free, about 5 minutes)

1. Go to https://console.cloud.google.com and create a project.
2. Open **APIs & Services → Library**, search for **YouTube Data API v3**, and click **Enable**.
3. Open **APIs & Services → Credentials → Create credentials → API key**.
4. Recommended: edit the key, set **Application restrictions → Websites**, and add your site address (for example `https://yourname.github.io/*`). Under **API restrictions**, allow only the YouTube Data API v3.

The free allowance is 10,000 units a day. Scanning a 50-video channel costs about 3 units, and each channel rescans once a day.

## 2. Put it on the web

YouTube won't play videos in a page opened straight from a file, so the page needs a web address.

**GitHub Pages (works on your phone and TV browser too):**
1. Create a new repository on GitHub and upload all the files in this folder.
2. Go to **Settings → Pages**, set the source to the `main` branch, and save.
3. After a minute it's live at `https://<your-username>.github.io/<repo-name>/`.

**Just on this computer:** in this folder, run `python3 -m http.server`, then open http://localhost:8000.

## 3. On your phone

Open the link, then:
- **iPhone:** Share → **Add to Home Screen**. It opens full screen like an app.
- **Android:** browser menu → **Install app** or **Add to Home screen**.

Hold the phone upright for the picture with the guide underneath. Turn it sideways for full-screen TV.
Swipe up or down on the picture to change channels, and tap it to show the controls.

## How it works

- **Live schedule.** Every channel runs on a clock-based schedule, so when you tune in, the show is already partway through. The next show starts from the beginning. The **Guide** shows the next three hours for every channel.
- **Daily lineup.** Each broadcast day starts at 4 AM. That's when channels rescan their links and get the day's order.
- **Pre-loading.** The channels above and below the one you're watching play silently in the background, so switching to them is instant. You can turn this down or off in Settings to save data.
- **Dead air.** If a video refuses to play (removed, blocked from embedding, or blocked in your country), the channel fills that slot with another of its videos. That device skips the video for a day, then tries again. **Settings → Retry skipped videos** tries them all right away, which is useful after turning a VPN on.

## Commercial breaks

1. In **Settings → Commercials**, paste links to vintage commercials, one per line. Playlists, channels and single videos all work. Long compilation videos are fine too: each break plays a slice of one. Searching YouTube for "90s commercials compilation" is a good start.
2. Pick a **break length** (1–4 minutes).
3. In each channel's settings, set **Commercial breaks** to *Between shows* or *Between and during shows*. "During" adds a break every 15 minutes in shows longer than 20 minutes.

Breaks appear in the guide as thin striped slots between shows.

## Sync between devices

- **Same schedule everywhere.** Every device with the same lineup shows the same thing at the same time. Each broadcast day starts at 4 AM, when channels pick up any new uploads and get a fresh order.
- **Shared lineup.** Your lineup is stored in a `lineup.json` file in your repository. Every device checks it when it opens, and every 15 minutes while it's running.

To publish lineup changes automatically, give Rabbit Ears a GitHub token on the device where you edit channels:

1. On github.com: your picture → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
2. Name it `Rabbit Ears`, and pick an expiration (up to a year).
3. **Repository access:** Only select repositories → `rabbit-ears`.
4. **Permissions:** Repository permissions → **Contents: Read and write**.
5. Generate it, copy it, and paste it into Rabbit Ears **Settings → Sync between devices**. Save.

From then on, saving in Settings updates every device. Without a token, tap **Download lineup.json** and upload that file to your repository the same way you upload `index.html`.

The token can only change files in this one repository, but treat it like a password: only add it on your own devices.

## Your own video files

Any channel can play your own videos alongside (or instead of) YouTube. Add a line to its links:

- `local:Folder name` plays the files in that folder.
- `local:` plays all your files.

**On a phone or computer:** Settings → **Your video files**. Type a folder name, tap **Add video files**, and pick them. They're copied into the browser on that device. MP4 works everywhere; MKV and AVI usually won't play on a phone.

**On the Raspberry Pi:** put files in `~/Videos/RabbitEars`, or in a folder called `RabbitEars` on a USB drive, with one folder per show. They show up within a minute. Files that aren't MP4 are converted automatically, which can take a while for big files on a Pi.

Every device knows about everyone's files (names and lengths only, shared through `lineup.json`), so schedules match. When it's time for a file a device doesn't have, that device plays one of its own files instead, and the guide shows the missing one with a dashed outline. Sharing the file list needs a GitHub token on the device that has the files.

## Raspberry Pi TV box

Turns a Raspberry Pi 4 or 5 into a box that boots straight into Rabbit Ears.

You need Raspberry Pi OS **with desktop**, an internet connection, and a keyboard for setup. A USB or Bluetooth remote works for watching.

1. Upload `rabbit-ears-pi.py` and `install-pi.sh` to your repository, next to `index.html`.
2. On the Pi, open **Terminal** and run:
   ```
   curl -fsSL https://weisser998-oss.github.io/rabbit-ears/install-pi.sh | bash
   ```
3. Paste your YouTube API key when asked. Optionally paste a GitHub token, so the Pi can share its file list with your phone.
4. In Google Cloud, add `http://localhost:8090/*` to your API key's website restrictions, next to your GitHub address.
5. Restart the Pi: `sudo reboot`.

**Remote:** ▲/▼ change channel. **OK** opens the guide; then ▲/▼ pick a channel and **OK** tunes to it. **Back** closes the guide. Number keys jump to a channel.

**Updates:** the Pi loads Rabbit Ears from your GitHub site each time it starts, so uploading a new `index.html` updates it too. It keeps a copy in case the internet is down. To update the helper itself, run the install command again.

**Smoothness:** the Pi doesn't pre-load other channels, because playing several YouTube videos at once is too much for a Pi 4. If YouTube is choppy, set the Pi's screen to 1280×720 in Raspberry Pi menu → Preferences → Screen Configuration.

**Getting to the desktop:** press Alt+F4 on a keyboard.

## Channel settings

Open **Settings** to edit the lineup. Each channel has:

- **Links**: one per line. Accepts a channel (`@handle` or link), a playlist, or a single video.
- **Shuffle**: Complete, None (upload order), or Partial (N videos in a row from the same link, in order, then a random jump).
- **Videos to scan per link**, and whether to take the **most recent** or a **random** selection.
- **Skip videos under 1 minute** to keep Shorts out.

Keyboard: `↑`/`↓` change channel, number keys jump to a channel, `G` guide, `M` mute, `F` full screen.

Your API key, volume and pre-load choice are saved per device. The lineup is shared through `lineup.json` (see Sync above).
