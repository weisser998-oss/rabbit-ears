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
- **Pre-loading.** The channels above and below the one you're watching play silently in the background, so switching to them is instant. You can turn this down or off in Settings to save data.
- **Daily refresh.** Each channel rescans its links once a day. The new lineup takes over when the show airing at that moment ends.
- **Dead air.** If a video refuses to play (removed, or blocked from embedding), the channel fills that slot with another of its videos and leaves the broken one out next time.

## Channel settings

Open **Settings** to edit the lineup. Each channel has:

- **Links**: one per line. Accepts a channel (`@handle` or link), a playlist, or a single video.
- **Shuffle**: Complete, None (upload order), or Partial (N videos in a row from the same link, in order, then a random jump).
- **Videos to scan per link**, and whether to take the **most recent** or a **random** selection.
- **Skip videos under 1 minute** to keep Shorts out.

Keyboard: `↑`/`↓` change channel, number keys jump to a channel, `G` guide, `M` mute, `F` full screen.

Your lineup is saved in each browser separately. Use **Settings → Backup** to copy it to another device.
