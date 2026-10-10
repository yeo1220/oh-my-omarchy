#!/usr/bin/env python3
"""Cover-color ambient wallpaper with durable recovery and supervised playback."""
import colorsys
import fcntl
import hashlib
import io
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import time
import urllib.parse
import urllib.request
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

STATE = Path.home() / '.local/state/omarchy/music-ambient'
LINK = Path.home() / '.local/state/omarchy/current/background'
RECOVERY = STATE / 'recovery.json'
FALLBACK = Path.home() / '.config/omarchy/backgrounds/graphite-atelier/02-champagne-ridge.png'
active = False
identifier = None
stopping = False
slot = 0


def log(message):
    print('[Ambient] ' + message, flush=True)


def run(args, timeout=4):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f'{args[0]}: {result.stderr.strip() or result.stdout.strip()}')
    return result.stdout.strip()


def owned(path):
    return str(path).startswith(str(STATE) + '/') or str(path).startswith('/tmp/omarchy-ambient/')


def current_background():
    return LINK.resolve()


def save_original():
    current = current_background()
    if not owned(current) and current.is_file():
        tmp = RECOVERY.with_suffix('.tmp')
        tmp.write_text(json.dumps({'background': str(current)}))
        tmp.replace(RECOVERY)
    elif not RECOVERY.exists():
        raise RuntimeError('Original wallpaper unavailable; refusing to replace it')


def restore():
    global active, identifier
    # Also recover after SIGKILL, a crash, or the previous implementation exiting.
    current = current_background()
    if owned(current):
        original = Path(json.loads(RECOVERY.read_text())['background']) if RECOVERY.exists() else FALLBACK
        if not original.is_file() or owned(original):
            raise RuntimeError('Saved original wallpaper is missing')
        run(['omarchy', 'theme', 'bg', 'set', str(original)])
        log('Original wallpaper restored')
    if active or RECOVERY.exists():
        run(['hyprctl', 'reload'])
    active = False
    identifier = None
    RECOVERY.unlink(missing_ok=True)


def palette(img):
    small = img.convert('RGB').resize((48, 48))
    candidates = []
    for rgb in small.getdata():
        h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in rgb))
        if .12 < l < .88 and s > .12:
            candidates.append((s * (1 - abs(l - .5)), h))
    candidates.sort(reverse=True)
    h1 = candidates[0][1] if candidates else .09
    h2 = next((h for _, h in candidates if .12 < min(abs(h - h1), 1 - abs(h - h1)) < .46), (h1 + .16) % 1)
    return [tuple(round(v * 255) for v in colorsys.hls_to_rgb(h, .52, .60)) for h in (h1, h2)]


def render(img, size, phase=0):
    """Broad pools of cover color, subtle texture and dark edges; no stretched art."""
    colors = palette(img)
    w, h = 320, max(90, round(320 * size[1] / size[0]))
    texture = ImageOps.fit(img.convert('RGB'), (w, h)).filter(ImageFilter.GaussianBlur(25))
    texture = ImageEnhance.Color(texture).enhance(.8)
    pixels = texture.load()
    field = Image.new('RGB', (w, h))
    out = field.load()
    for y in range(h):
        ny = y / h
        for x in range(w):
            nx = x / w
            a = math.exp(-(((nx - .24) / .48) ** 2 + ((ny - .34) / .65) ** 2) * 1.6)
            b = math.exp(-(((nx - .78) / .46) ** 2 + ((ny - .64) / .60) ** 2) * 1.7)
            edge = max(.45, 1 - .5 * ((nx - .5) ** 2 + (ny - .5) ** 2))
            out[x, y] = tuple(min(255, round((9 + colors[0][i] * a * .44 + colors[1][i] * b * .38 + pixels[x, y][i] * .12) * edge)) for i in range(3))
    return field.resize(size, Image.Resampling.BICUBIC), colors


def cover(art_url, track_url, title):
    try:
        if art_url.startswith('file://'):
            with Image.open(urllib.parse.unquote(urllib.parse.urlparse(art_url).path)) as img:
                return img.convert('RGB')
        if art_url.startswith(('https://', 'http://')):
            req = urllib.request.Request(art_url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=3) as response:
                data = response.read(10 * 1024 * 1024)
            with Image.open(io.BytesIO(data)) as img:
                return img.convert('RGB')
        if track_url.startswith('file://'):
            path = urllib.parse.unquote(urllib.parse.urlparse(track_url).path)
            output = STATE / 'cover.png'
            run(['ffmpeg', '-loglevel', 'error', '-y', '-i', path, '-an', '-frames:v', '1', str(output)], timeout=3)
            with Image.open(output) as img:
                return img.convert('RGB')
    except Exception as exc:
        log(f'Cover unavailable; using color gradient ({type(exc).__name__})')
    hue = int.from_bytes(hashlib.sha256(title.encode()).digest()[:2], 'big') / 65535
    return Image.new('RGB', (64, 64), tuple(round(v * 255) for v in colorsys.hls_to_rgb(hue, .5, .6)))


def playback():
    result = subprocess.run(['playerctl', '-a', 'metadata', '--format', '{{playerName}};;{{status}};;{{mpris:artUrl}};;{{xesam:url}};;{{xesam:title}}'], capture_output=True, text=True, timeout=2)
    for line in result.stdout.splitlines():
        parts = line.split(';;', 4)
        if len(parts) == 5 and parts[1] == 'Playing':
            return tuple(parts[2:])
    return None


def apply(track):
    global active, identifier, slot
    img = cover(*track)
    monitors = json.loads(run(['hyprctl', 'monitors', '-j']))
    monitor = next((m for m in monitors if m.get('focused')), monitors[0])
    size = (monitor['width'], monitor['height'])
    wall, colors = render(img, size)
    # Art downloads can outlive playback; never apply a stale track.
    if stopping or playback() != track:
        return
    save_original()
    active = True  # Keep recovery pending even if either IPC command fails.
    slot = 1 - slot
    path = STATE / f'wall-{slot}.png'
    wall.save(path)
    run(['omarchy', 'theme', 'bg', 'set', str(path)])
    c1, c2 = [''.join(f'{v:02x}' for v in c) for c in colors]
    run(['hyprctl', 'eval', "hl.config({ general = { col = { active_border = { colors = { 'rgba(" + c1 + "bb)', 'rgba(" + c2 + "bb)' }, angle = 45 }, inactive_border = 'rgba(" + c1 + "22)' } } })"])
    identifier = track
    log('Ambient applied')


def stop(signum, frame):
    global stopping
    stopping = True


def main():
    global identifier
    STATE.mkdir(parents=True, exist_ok=True)
    lock = (STATE / 'daemon.lock').open('w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    restore()
    log('Daemon started')
    idle_since = None
    try:
        while not stopping:
            try:
                track = playback()
                if track:
                    idle_since = None
                    if track != identifier:
                        apply(track)
                else:
                    idle_since = idle_since or time.monotonic()
                    if (active or owned(current_background())) and time.monotonic() - idle_since >= 1.5:
                        restore()
            except Exception as exc:
                log(f'Retrying after error: {exc}')
                if active:
                    try:
                        restore()
                    except Exception as restore_error:
                        log(f'Recovery pending: {restore_error}')
            time.sleep(.5)
    finally:
        restore()


if __name__ == '__main__':
    main()
