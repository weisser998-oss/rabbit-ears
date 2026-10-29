#!/usr/bin/env python3
"""Rabbit Ears helper for Raspberry Pi.

Runs at http://localhost:8090 and:
  - serves the Rabbit Ears app from your GitHub Pages site (keeping a copy for when the internet is down),
  - serves your own video files from ~/Videos/RabbitEars and any USB drive,
  - converts videos that aren't MP4 into MP4 in the background,
  - hands the app its settings (API key, GitHub token) from ~/.rabbit-ears/config.json.
"""
import hashlib
import json
import mimetypes
import os
import re
import shutil
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

BASE = Path.home() / ".rabbit-ears"
CONFIG = json.loads((BASE / "config.json").read_text())
SITE = CONFIG["site"].rstrip("/") + "/"
PORT = int(CONFIG.get("port", 8090))
SITE_CACHE = BASE / "site-cache"
CONVERTED = BASE / "converted"
PROBES = BASE / "probes.json"

VIDEO_EXTS = {".mp4", ".m4v", ".mov", ".mkv", ".avi", ".webm", ".wmv", ".flv", ".mpg", ".mpeg", ".ts", ".m2ts", ".3gp", ".divx"}
DIRECT_EXTS = {".mp4", ".m4v", ".webm"}
DIRECT_VIDEO = {"h264", "vp8", "vp9", "av1"}
DIRECT_AUDIO = {None, "aac", "mp3", "opus", "vorbis"}
SCAN_EVERY = 60

library = {"files": [], "converting": [], "by_path": {}}
lock = threading.Lock()


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


# ---------- finding videos ----------

def media_roots():
    """~/Videos/RabbitEars, plus each USB drive (its RabbitEars folder if it has one, otherwise the whole drive)."""
    roots = [Path.home() / "Videos" / "RabbitEars"]
    for media in (Path("/media") / os.environ.get("USER", ""), Path("/media"), Path("/mnt")):
        if not media.is_dir():
            continue
        for drive in sorted(media.iterdir()):
            if drive.is_dir() and not drive.name.startswith(".") and os.path.ismount(drive):
                sub = drive / "RabbitEars"
                roots.append(sub if sub.is_dir() else drive)
    seen, out = set(), []
    for r in roots:
        if r.is_dir() and r.resolve() not in seen:
            seen.add(r.resolve())
            out.append(r)
    return out


def walk(root, depth=4):
    try:
        entries = sorted(root.iterdir())
    except OSError:
        return
    for e in entries:
        if e.name.startswith(".") or e.name.startswith("._"):
            continue
        if e.is_dir() and depth > 0:
            yield from walk(e, depth - 1)
        elif e.is_file() and e.suffix.lower() in VIDEO_EXTS:
            yield e


def load_probes():
    try:
        return json.loads(PROBES.read_text())
    except (OSError, ValueError):
        return {}


def probe(path, probes):
    st = path.stat()
    key = f"{path}|{st.st_size}|{int(st.st_mtime)}"
    if key in probes:
        return key, probes[key]
    info = {"dur": 0, "v": None, "a": None}
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration:stream=codec_type,codec_name", "-of", "json", str(path)],
            capture_output=True, text=True, timeout=60).stdout
        j = json.loads(out or "{}")
        info["dur"] = float(j.get("format", {}).get("duration") or 0)
        for s in j.get("streams", []):
            if s.get("codec_type") == "video" and not info["v"]:
                info["v"] = s.get("codec_name")
            if s.get("codec_type") == "audio" and not info["a"]:
                info["a"] = s.get("codec_name")
    except (OSError, ValueError, subprocess.TimeoutExpired):
        pass
    probes[key] = info
    return key, info


def converted_path(key):
    return CONVERTED / (hashlib.sha1(key.encode()).hexdigest()[:20] + ".mp4")


def plays_directly(path, info):
    return path.suffix.lower() in DIRECT_EXTS and info["v"] in DIRECT_VIDEO and info["a"] in DIRECT_AUDIO


def scan():
    probes, files, todo, used = load_probes(), [], [], set()
    for root in media_roots():
        for path in walk(root):
            rel = path.relative_to(root).as_posix()
            if any(f["path"] == rel for f in files):
                continue  # same file name on two drives: the first one wins
            key, info = probe(path, probes)
            if info["dur"] < 1 or not info["v"]:
                continue
            serve = path
            if not plays_directly(path, info):
                serve = converted_path(key)
                used.add(serve.name)
                if not serve.exists():
                    todo.append((path, serve, info))
                    continue
            parts = rel.split("/")
            files.append({"path": rel, "folder": parts[0] if len(parts) > 1 else "", "name": parts[-1],
                          "dur": round(info["dur"]), "size": serve.stat().st_size, "_file": str(serve)})
    PROBES.write_text(json.dumps(probes))
    # Converted copies of files that are gone get cleaned up.
    for old in CONVERTED.glob("*.mp4"):
        if old.name not in used and not old.name.endswith(".part.mp4"):
            old.unlink(missing_ok=True)
    with lock:
        library["files"] = files
        library["by_path"] = {f["path"]: f["_file"] for f in files}
        library["converting"] = [p.name for p, _, _ in todo]
    return todo


# ---------- converting ----------

def convert(src, dst, info):
    """Make an MP4 the browser can play. Copies streams that are already fine; re-encodes the rest."""
    tmp = dst.with_name(dst.stem + ".part.mp4")
    copy_video = info["v"] == "h264"
    copy_audio = info["a"] in ("aac", "mp3")
    audio = ["-c:a", "copy"] if copy_audio else ["-c:a", "aac", "-b:a", "160k", "-ac", "2"]
    attempts = []
    if copy_video:
        attempts.append(["-c:v", "copy"])
    else:
        # The Pi 4's hardware encoder is much faster; fall back to software if it isn't available.
        attempts.append(["-c:v", "h264_v4l2m2m", "-b:v", "5M", "-pix_fmt", "yuv420p", "-vf", "scale='min(1920,iw)':-2"])
        attempts.append(["-c:v", "libx264", "-preset", "veryfast", "-crf", "22", "-pix_fmt", "yuv420p", "-vf", "scale='min(1920,iw)':-2"])
    for video in attempts:
        log("converting", src.name, "with", video[1])
        cmd = ["ffmpeg", "-y", "-v", "error", "-i", str(src), "-map", "0:v:0", "-map", "0:a:0?", *video, *audio,
               "-movflags", "+faststart", str(tmp)]
        try:
            if subprocess.run(cmd, timeout=6 * 3600).returncode == 0 and tmp.exists() and tmp.stat().st_size > 0:
                tmp.rename(dst)
                log("converted", src.name)
                return True
        except (OSError, subprocess.TimeoutExpired):
            pass
        tmp.unlink(missing_ok=True)
    log("couldn't convert", src.name)
    return False


def library_loop():
    failed = set()
    while True:
        try:
            todo = scan()
            for src, dst, info in todo:
                if str(src) in failed:
                    continue
                if not convert(src, dst, info):
                    failed.add(str(src))
                scan()
        except Exception as e:  # keep running whatever happens
            log("scan error:", e)
        time.sleep(SCAN_EVERY)


# ---------- web server ----------

class Handler(BaseHTTPRequestHandler):
    server_version = "RabbitEars"

    def log_message(self, *a):
        pass

    def send_json(self, obj):
        body = json.dumps(obj).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/api/config":
            m = re.match(r"https://([\w-]+)\.github\.io/([^/]*)", SITE)
            repo = {"owner": m.group(1), "name": m.group(2) or f"{m.group(1)}.github.io"} if m else None
            return self.send_json({"apiKey": CONFIG.get("apiKey", ""), "ghToken": CONFIG.get("ghToken", ""), "repo": repo,
                                   "preload": CONFIG.get("preload", "off"), "autostart": True,
                                   "mediaRoots": [str(r).replace(str(Path.home()), "~") for r in media_roots()]})
        if path == "/api/library":
            with lock:
                files = [{k: v for k, v in f.items() if k != "_file"} for f in library["files"]]
                return self.send_json({"files": files, "converting": list(library["converting"])})
        if path.startswith("/media/"):
            rel = urllib.parse.unquote(path[len("/media/"):])
            with lock:
                real = library["by_path"].get(rel)
            if not real:
                return self.send_error(404)
            return self.send_file(Path(real))
        return self.proxy(path)

    def send_file(self, p):
        try:
            size = p.stat().st_size
            f = open(p, "rb")
        except OSError:
            return self.send_error(404)
        with f:
            start, end = 0, size - 1
            rng = self.headers.get("Range")
            m = re.match(r"bytes=(\d*)-(\d*)", rng or "")
            if m:
                a, b = m.groups()
                if a:
                    start, end = int(a), int(b) if b else size - 1
                elif b:
                    start = max(0, size - int(b))
                end = min(end, size - 1)
                if start > end:
                    self.send_response(416)
                    self.send_header("Content-Range", f"bytes */{size}")
                    self.end_headers()
                    return
            self.send_response(206 if m else 200)
            self.send_header("Content-Type", mimetypes.guess_type(p.name)[0] or "video/mp4")
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Content-Length", str(end - start + 1))
            if m:
                self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
            self.end_headers()
            f.seek(start)
            left = end - start + 1
            try:
                while left > 0:
                    chunk = f.read(min(1 << 20, left))
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    left -= len(chunk)
            except (BrokenPipeError, ConnectionResetError):
                pass

    def proxy(self, path):
        """Serve the app from GitHub Pages, so uploading a new index.html updates the Pi too."""
        rel = path.lstrip("/") or "index.html"
        if ".." in rel.split("/"):
            return self.send_error(404)
        cached = SITE_CACHE / rel
        query = urllib.parse.urlparse(self.path).query
        try:
            req = urllib.request.Request(SITE + urllib.parse.quote(rel) + (f"?{query}" if query else ""),
                                         headers={"Cache-Control": "no-cache", "User-Agent": "RabbitEars-Pi"})
            with urllib.request.urlopen(req, timeout=10) as r:
                body, ctype = r.read(), r.headers.get("Content-Type", "")
            cached.parent.mkdir(parents=True, exist_ok=True)
            cached.write_bytes(body)
        except urllib.error.HTTPError as e:
            return self.send_error(e.code)
        except (OSError, urllib.error.URLError):
            if not cached.exists():
                return self.send_error(502, "Can't reach the Rabbit Ears site and there's no saved copy yet.")
            body, ctype = cached.read_bytes(), mimetypes.guess_type(rel)[0] or "application/octet-stream"
        self.send_response(200)
        self.send_header("Content-Type", ctype or "application/octet-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    for d in (SITE_CACHE, CONVERTED, Path.home() / "Videos" / "RabbitEars"):
        d.mkdir(parents=True, exist_ok=True)
    if not shutil.which("ffprobe"):
        log("ffprobe is missing: install it with  sudo apt install ffmpeg")
    threading.Thread(target=library_loop, daemon=True).start()
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    server.daemon_threads = True
    log(f"Rabbit Ears helper running at http://localhost:{PORT}/ for {SITE}")
    server.serve_forever()


if __name__ == "__main__":
    main()
