from pathlib import Path
import os
import tempfile
import uuid
import zipfile
from urllib.parse import urlparse, unquote
from .common import STATE, HOME, update_json, read_json

PATH = STATE / 'shelf.json'


def normalize(value):
    value = value.strip()
    if value.startswith('file:'):
        parsed = urlparse(value)
        if parsed.netloc not in ('', 'localhost'):
            raise ValueError('로컬 파일만 추가할 수 있습니다.')
        value = unquote(parsed.path)
    parsed = urlparse(value)
    if parsed.scheme in ('http', 'https') and parsed.netloc:
        return {'kind': 'url', 'value': value, 'name': value}
    path = Path(value).expanduser().absolute()
    if not path.exists():
        raise ValueError('파일을 찾을 수 없습니다: ' + value)
    return {'kind': 'file', 'value': str(path), 'name': path.name}


def items():
    return read_json(PATH, [])


def add(values):
    entries = [normalize(v) for v in values if v.strip()]
    def mutate(rows):
        existing = {r['value'] for r in rows}
        for e in entries:
            if e['value'] not in existing:
                rows.append(dict(e, id=uuid.uuid4().hex))
                existing.add(e['value'])
    update_json(PATH, [], mutate)


def remove(ids):
    update_json(PATH, [], lambda rows: rows.__setitem__(slice(None), [r for r in rows if r['id'] not in ids]))


def archive(rows, destination=None):
    destination = Path(destination or HOME / 'Downloads')
    destination.mkdir(parents=True, exist_ok=True)
    target = destination / ('Orbit-Shelf-' + uuid.uuid4().hex[:8] + '.zip')
    fd, temp = tempfile.mkstemp(dir=destination, prefix='.orbit-zip-')
    os.close(fd)
    count = total = 0
    names = set()
    try:
        with zipfile.ZipFile(temp, 'w', zipfile.ZIP_DEFLATED) as out:
            for row in rows:
                base = row['name'] if row['kind'] == 'file' else 'link.url'
                original = base
                i = 1
                while base in names:
                    base = f'{i}-{original}'; i += 1
                names.add(base)
                if row['kind'] == 'url':
                    out.writestr(base, '[InternetShortcut]\nURL=' + row['value'] + '\n')
                    continue
                path = Path(row['value'])
                if path.is_symlink():
                    raise ValueError('바로가기 파일은 원본 경로를 선반에 추가해 주세요: ' + str(path))
                if not path.exists():
                    raise ValueError('원본이 없어 압축을 중단했습니다: ' + str(path))
                files = [path] if path.is_file() else sorted(path.rglob('*'))
                if path.is_dir():
                    out.writestr(base + '/', '')
                for f in files:
                    if f.is_symlink():
                        continue
                    if f.is_file():
                        count += 1; total += f.stat().st_size
                        if count > 10000 or total > 2 * 1024**3:
                            raise ValueError('선반 압축은 최대 10,000개 파일 / 2GB까지 지원합니다.')
                        arc = base if path.is_file() else base + '/' + str(f.relative_to(path))
                        out.write(f, arc)
        os.replace(temp, target)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)
    return str(target)
