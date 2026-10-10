"""Save window identities and restore apps, workspaces and floating geometry."""
import os
from pathlib import Path
import subprocess
import time
import uuid
from .common import HOME, STATE, clients, hypr, dispatch, read_json, update_json, atomic_json

PATH = STATE / 'scenes.json'


def launch_for(c):
    app = c.get('class', '').lower()
    cwd = str(HOME / 'Work')
    try:
        candidate = Path(f'/proc/{int(c["pid"])}/cwd').resolve(strict=True)
        if candidate.is_dir():
            cwd = str(candidate)
    except (OSError, KeyError):
        pass
    if app == 'foot':
        return ['foot', '--working-directory=' + cwd]
    if app == 'alacritty': return ['alacritty', '--working-directory', cwd]
    if app == 'kitty': return ['kitty', '--directory', cwd]
    if app == 'com.mitchellh.ghostty': return ['ghostty', '--working-directory=' + cwd]
    if app == 'chromium':
        return ['chromium', '--new-window']
    if app in ('com.obsproject.studio', 'obs'):
        return ['obs']
    if app in ('org.gnome.nautilus', 'nautilus'):
        return ['nautilus', str(HOME / 'Work')]
    return []


def entry(c):
    return {k: c.get(k) for k in ('address', 'stableId', 'pid', 'class', 'title', 'at', 'size', 'floating', 'fullscreen', 'monitor')} | {
        'workspace': c['workspace']['name'], 'launch': launch_for(c)}


def capture(name, current_only=False):
    if not name.strip():
        raise ValueError('작업 환경 이름을 입력하세요.')
    windows = clients()
    if current_only:
        current = hypr('activeworkspace')['name']
        windows = [c for c in windows if c['workspace']['name'] == current]
    return {'id': uuid.uuid4().hex, 'name': name.strip()[:80], 'created': time.time(),
            'session': os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', ''),
            'windows': [entry(c) for c in windows]}


def save(name, current_only=False):
    scene = capture(name, current_only)
    update_json(PATH, [], lambda rows: rows.append(scene))
    return scene


def all_scenes():
    return read_json(PATH, [])


def remove(scene_id):
    update_json(PATH, [], lambda rows: rows.__setitem__(slice(None), [s for s in rows if s['id'] != scene_id]))


def matching(saved, live, used, same_session):
    candidates = [c for c in live if c['address'] not in used]
    if same_session and saved.get('stableId'):
        exact = [c for c in candidates if c.get('stableId') == saved['stableId'] and c.get('pid') == saved.get('pid')]
        if exact:
            return exact[0]
    same = [c for c in candidates if c['class'] == saved['class']]
    title = [c for c in same if c['title'] == saved['title']]
    if len(title) == 1:
        return title[0]
    # Templates intentionally reuse an app; ambiguous saved windows never do.
    if saved.get('template') and same:
        return same[0]
    return None


def restore(scene, launch_missing=True):
    # Save a reversible checkpoint before touching any current windows.
    atomic_json(STATE / 'before-restore.json', capture('복원 전'))
    used, report = set(), []
    same = scene.get('session') == os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
    for saved in scene['windows']:
        live = clients()
        c = matching(saved, live, used, same)
        if c is None and launch_missing and saved.get('launch'):
            before = {w['address'] for w in live}
            subprocess.Popen(saved['launch'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            for _ in range(60):
                time.sleep(0.15)
                new = [w for w in clients() if w['address'] not in before and w['class'].lower() == saved['class'].lower()]
                if new:
                    c = new[0]
                    break
        if c is None:
            report.append('건너뜀: ' + saved['title'])
            continue
        used.add(c['address'])
        window = 'address:' + c['address']
        target = str(saved['workspace'])
        if not target.isdigit() and not target.startswith('special:'):
            target = 'name:' + target
        dispatch('window.move', window=window, workspace=target, follow=False)
        if not saved.get('template'):
            if c.get('fullscreen'):
                dispatch('window.fullscreen', window=window, action='unset')
            dispatch('window.float', window=window, action='enable' if saved['floating'] else 'disable')
            if saved['floating']:
                dispatch('window.resize', window=window, x=max(100, saved['size'][0]), y=max(80, saved['size'][1]))
                dispatch('window.move', window=window, x=saved['at'][0], y=saved['at'][1])
            if saved.get('fullscreen'):
                dispatch('window.fullscreen', window=window, action='set', mode='fullscreen' if saved['fullscreen'] == 2 else 'maximized')
        report.append('복원: ' + saved['title'])
    return '\n'.join(report) or '저장된 창이 없습니다.'


def seed():
    if PATH.exists():
        return
    def app(cls, title, workspace, launch):
        return dict(template=True, **{'class': cls}, title=title, workspace=str(workspace), launch=launch)
    work = str(HOME / 'Work')
    templates = [
        ('개발', [app('foot', '작업 터미널', 2, ['foot', '--working-directory=' + work]), app('chromium', '브라우저', 2, ['chromium', '--new-window']), app('org.gnome.Nautilus', '작업 폴더', 3, ['nautilus', work])]),
        ('원격', [app('orbit.remote', '원격 작업 선택', 4, ['foot', '--app-id=orbit.remote', '-e', str(HOME / '.local/bin/remote-work')]), app('chromium', '원격 작업 자료', 4, ['chromium', '--new-window'])]),
        ('방송', [app('com.obsproject.Studio', 'OBS', 5, ['obs']), app('chromium', '방송 자료', 5, ['chromium', '--new-window'])])]
    atomic_json(PATH, [dict(id=uuid.uuid4().hex, name=n, created=time.time(), session='', windows=w) for n,w in templates])
