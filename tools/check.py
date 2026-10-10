#!/usr/bin/env python3
"""Offline syntax and accidental credential checks; never runs desktop helpers."""
import ast
import json
from pathlib import Path
import re
import subprocess
import sys
import tomllib

ROOT = Path(__file__).resolve().parents[1]
patterns = [
    r'gh[pousr]_[A-Za-z0-9]{30,}',
    r'github_pat_[A-Za-z0-9_]{30,}',
    r'sk-(?:proj-)?[A-Za-z0-9_-]{32,}',
    r'AKIA[A-Z0-9]{16}',
    r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
]
count = 0
for path in sorted(ROOT.rglob('*')):
    if not path.is_file() or any(p in {'.git', '__pycache__'} for p in path.relative_to(ROOT).parts):
        continue
    if path.suffix in {'.png', '.jpg', '.pyc'}:
        continue
    text = path.read_text()
    if any(re.search(pattern, text) for pattern in patterns):
        raise SystemExit(f'Possible credential: {path.relative_to(ROOT)}')
    if path.suffix == '.py' or (text.startswith('#!') and 'python' in text.splitlines()[0]):
        ast.parse(text, filename=str(path))
    elif text.startswith('#!') and re.search(r'\b(?:ba)?sh\b', text.splitlines()[0]):
        subprocess.run(['bash', '-n', str(path)], check=True)
    if path.suffix == '.json':
        json.loads(text)
    if path.suffix == '.toml':
        tomllib.loads(text)
    count += 1
print(f'PASS: {count} text files checked (syntax and common credential patterns)')
subprocess.run([sys.executable, str(ROOT / 'apps/orbit-tools/tests/test_tools.py')], check=True)
subprocess.run([sys.executable, str(ROOT / 'tests/test_ambient.py')], check=True)
