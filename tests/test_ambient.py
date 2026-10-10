import importlib.util
import json
from pathlib import Path
import tempfile
from unittest.mock import patch
from PIL import Image, ImageStat
spec = importlib.util.spec_from_file_location('ambient', str(Path(__file__).resolve().parents[1] / 'config/hypr/scripts/music-ambient.py'))
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    a.STATE = root / 'ambient'
    a.STATE.mkdir()
    a.RECOVERY = a.STATE / 'recovery.json'
    a.LINK = root / 'background'
    original = root / 'original.png'
    Image.new('RGB', (10, 10)).save(original)
    a.LINK.symlink_to(original)
    a.save_original()
    assert json.loads(a.RECOVERY.read_text())['background'] == str(original)
    wall = a.STATE / 'wall-1.png'
    Image.new('RGB', (10, 10)).save(wall)
    a.LINK.unlink()
    a.LINK.symlink_to(wall)
    a.save_original()
    assert json.loads(a.RECOVERY.read_text())['background'] == str(original)
    def command(args, **kwargs):
        if args[:4] == ['omarchy', 'theme', 'bg', 'set']:
            a.LINK.unlink()
            a.LINK.symlink_to(args[4])
        return ''
    with patch.object(a, 'run', side_effect=RuntimeError('IPC failure')):
        try: a.restore()
        except RuntimeError: pass
    assert a.RECOVERY.exists(), 'Failed restoration must retain recovery'
    with patch.object(a, 'run', side_effect=command): a.restore()
    assert a.LINK.resolve() == original and not a.RECOVERY.exists()
    a.save_original()
    alternate = root / 'user-changed.png'
    Image.new('RGB', (10, 10)).save(alternate)
    a.LINK.unlink()
    a.LINK.symlink_to(alternate)
    with patch.object(a, 'run', side_effect=command): a.restore()
    assert a.LINK.resolve() == alternate, 'Preserve manual wallpaper changes'
    with patch.object(a, 'cover', return_value=Image.new('RGB', (10, 10))), patch.object(a, 'run', return_value='[{"width":320,"height":180}]'), patch.object(a, 'playback', return_value=None), patch.object(a, 'save_original') as save:
        a.apply(('art', 'url', 'title'))
        save.assert_not_called()
wall, _ = a.render(Image.new('RGB', (64, 64), '#bd7958'), (1366, 768))
assert wall.size == (1366, 768)
assert max(ImageStat.Stat(wall).stddev) > 8, 'Fallback must not be flat'
print('PASS: durable recovery, failed restore retry, manual changes, stale playback, gradient')
