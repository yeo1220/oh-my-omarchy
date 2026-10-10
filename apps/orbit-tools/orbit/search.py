"""Incremental local document index; Unicode substring search and content excerpts."""
import os
from pathlib import Path
import sqlite3
import time
import zipfile
import xml.etree.ElementTree as ET
from contextlib import closing
from .common import HOME, STATE, CONFIG, atomic_json, read_json, run

DB = STATE / 'search.sqlite3'
ROOTS = CONFIG / 'search-roots.json'
TEXT = {'.txt','.md','.rst','.py','.js','.ts','.tsx','.jsx','.json','.yaml','.yml','.toml','.csv','.html','.css','.sh','.lua','.qml','.sql','.xml','.tex'}
SKIP = {'node_modules', '__pycache__', 'venv', '.venv', 'target', 'dist', 'build', 'backups', 'backup', 'references'}


def roots():
    if not ROOTS.exists():
        atomic_json(ROOTS, [str(HOME / x) for x in ('Documents', 'Work', 'Downloads')])
    return read_json(ROOTS, [])


def connect():
    DB.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    db = sqlite3.connect(DB, timeout=20)
    os.chmod(DB, 0o600)
    db.execute('PRAGMA journal_mode=WAL')
    db.execute('CREATE TABLE IF NOT EXISTS files (path TEXT PRIMARY KEY, name TEXT, mtime INTEGER, size INTEGER, body TEXT)')
    db.execute('CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)')
    db.execute("CREATE VIRTUAL TABLE IF NOT EXISTS search_fts USING fts5(path UNINDEXED, name, body, tokenize='trigram')")
    return db


def extract(path):
    if path.is_dir():
        return ''
    if path.stat().st_size > 20 * 1024**2:
        return ''
    suffix = path.suffix.lower()
    if suffix in TEXT:
        with path.open('rb') as f:
            data = f.read(2 * 1024**2)
        return '' if b'\x00' in data[:1000] else data.decode('utf-8', errors='replace')
    if suffix == '.pdf':
        return run(['pdftotext', '-f', '1', '-l', '100', '-layout', str(path), '-'], timeout=5)[:2 * 1024**2]
    if suffix == '.docx':
        with zipfile.ZipFile(path) as z:
            info = z.getinfo('word/document.xml')
            if info.file_size > 5 * 1024**2:
                return ''
            doc = ET.fromstring(z.read(info))
            ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
            return '\n'.join(''.join(p.itertext()) for p in doc.findall('.//w:p', ns))[:2 * 1024**2]
    return ''


def walk(selected_roots):
    seen = set()
    for folder in selected_roots:
        base = Path(folder).expanduser()
        if not base.is_dir():
            continue
        for parent, dirs, files in os.walk(base, followlinks=False):
            dirs[:] = [d for d in dirs if not d.startswith('.') and d not in SKIP and not d.startswith('backup-') and not (Path(parent)/d).is_symlink()]
            for name in dirs:
                p = Path(parent)/name
                key = str(p.absolute())
                if key not in seen:
                    seen.add(key); yield p
            for name in files:
                p = Path(parent)/name
                if name.startswith('.') or p.is_symlink() or p.suffix.lower() in {'.key','.pem','.p12','.pfx'}:
                    continue
                key = str(p.absolute())
                if key not in seen:
                    seen.add(key); yield p


def index(selected_roots=None):
    selected_roots = roots() if selected_roots is None else selected_roots
    seen, updated, errors = set(), 0, []
    with closing(connect()) as db, db:
        known = {p: (m,s) for p,m,s in db.execute('SELECT path, mtime, size FROM files')}
        for path in walk(selected_roots):
            key = str(path.absolute()); seen.add(key)
            if len(seen) > 50000:
                raise ValueError('검색 폴더가 너무 큽니다. 50,000개 이하로 범위를 나누세요.')
            try:
                stat = path.stat()
                if known.get(key) == (stat.st_mtime_ns, stat.st_size):
                    continue
                body = extract(path)
                db.execute('INSERT OR REPLACE INTO files VALUES (?,?,?,?,?)', (key,path.name,stat.st_mtime_ns,stat.st_size,body))
                db.execute('DELETE FROM search_fts WHERE path=?', (key,))
                db.execute('INSERT INTO search_fts VALUES (?,?,?)', (key,path.name,body))
                updated += 1
            except (OSError, RuntimeError, zipfile.BadZipFile, KeyError, ET.ParseError) as e:
                errors.append(path.name + ': ' + str(e)[:100])
        for key in set(known) - seen:
            db.execute('DELETE FROM files WHERE path=?', (key,))
            db.execute('DELETE FROM search_fts WHERE path=?', (key,))
        db.execute('INSERT OR REPLACE INTO meta VALUES (?,?)', ('indexed_at', str(time.time())))
    return {'count': len(seen), 'updated': updated, 'errors': errors[:20]}


def find(query, limit=60):
    query = query.strip()[:200]
    if not query:
        return []
    with closing(connect()) as db, db:
        if len(query) >= 3:
            expression = '"' + query.replace('"', '""') + '"'
            hits = db.execute('SELECT path,name,body FROM search_fts WHERE search_fts MATCH ? ORDER BY rank LIMIT ?', (expression,limit)).fetchall()
        else:
            escaped = query.replace('\\','\\\\').replace('%','\\%').replace('_','\\_')
            pattern = '%' + escaped + '%'
            clause = "name LIKE ? ESCAPE '\\' OR body LIKE ? ESCAPE '\\'" if len(query)>1 else "name LIKE ? ESCAPE '\\'"
            params = (pattern,pattern,limit) if len(query)>1 else (pattern,limit)
            hits = db.execute('SELECT path,name,body FROM files WHERE ' + clause + ' LIMIT ?', params).fetchall()
    result=[]
    for path,name,body in hits:
        if not Path(path).exists():
            continue
        pos=body.casefold().find(query.casefold())
        excerpt = body[max(0,pos-60):max(0,pos-60)+220].replace('\n',' ') if pos>=0 else path
        result.append({'path':path,'name':name,'excerpt':excerpt})
    return result


def last_indexed():
    with closing(connect()) as db, db:
        row=db.execute("SELECT value FROM meta WHERE key='indexed_at'").fetchone()
        return float(row[0]) if row else 0
