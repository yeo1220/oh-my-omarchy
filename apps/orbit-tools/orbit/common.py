import fcntl
import json
import os
from pathlib import Path
import subprocess
import tempfile

HOME = Path.home()
STATE = Path(os.environ.get('ORBIT_TOOLS_STATE', str(HOME / '.local/state/orbit-tools')))
CONFIG = HOME / '.config/orbit-tools'


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, name = tempfile.mkstemp(dir=path.parent, prefix='.write-')
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(value, f, ensure_ascii=False, indent=2)
            f.flush()
            os.fsync(f.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def read_json(path, default):
    return json.loads(path.read_text()) if path.exists() else default


def update_json(path, default, callback):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with path.with_suffix('.lock').open('a') as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        value = read_json(path, default)
        result = callback(value)
        atomic_json(path, value)
        return result


def run(argv, **kw):
    result = subprocess.run(argv, capture_output=True, text=True, timeout=kw.pop('timeout', 8), **kw)
    if result.returncode:
        raise RuntimeError((result.stderr or result.stdout or f'실행 실패: {argv[0]}').strip()[:500])
    return result.stdout


def hypr(query):
    return json.loads(run(['hyprctl', query, '-j']))


def lua(value):
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return str(value)
    # JSON's non-ASCII literal string representation is valid Lua here.
    return json.dumps(str(value), ensure_ascii=False)


def dispatch(method, **args):
    table = ', '.join(f'{k} = {lua(v)}' for k, v in args.items())
    out = run(['hyprctl', 'dispatch', f'hl.dsp.{method}({{ {table} }})'])
    if out.strip() != 'ok':
        raise RuntimeError(out.strip())


def clients():
    return [c for c in hypr('clients') if c.get('mapped') and c.get('class') != 'io.lovehouse.OrbitTools']


def copy_text(text):
    # wl-copy forks a clipboard owner. Do not capture inherited output pipes:
    # communicate() would wait for that owner, which intentionally stays alive.
    subprocess.run(['wl-copy', '--type', 'text/plain;charset=utf-8'], input=text,
                   text=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                   check=True, timeout=3)


def clipboard():
    return run(['wl-paste', '--no-newline', '--type', 'text'], timeout=3)
