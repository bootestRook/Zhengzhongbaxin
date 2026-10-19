"""Create and verify the exact portable ZIP that will be shared."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RUNTIME = ROOT / 'build/windows'
ARCHIVE = ROOT / 'build/守城战斗试玩-Windows-20261016.zip'

manifest = json.loads((RUNTIME / 'package-manifest.json').read_text(encoding='utf-8'))
expected = {item['path']: item['sha256'] for item in manifest['files']}
mapping = {'启动游戏.exe': 'defense-demo.exe', '启动游戏.pck': 'defense-demo.pck'}
instructions = '''守城战斗试玩版（Windows 64位）

1. 先将整个压缩包解压到一个文件夹。
2. 双击“启动游戏.exe”开始游戏。
3. “启动游戏.pck”必须与EXE放在同一个文件夹，请勿删除或单独移动。

无需安装Godot、Python或打开工程，离线即可运行。
请勿直接在压缩包预览窗口内运行EXE。

点击开始挑战，选择英雄和强化；英雄自动战斗。
当前默认五名英雄各有一项初始技能。短按底栏技能图标查看说明，
战斗中按住约0.4秒查看对应英雄的施放距离，松开即隐藏。
每局共有2次刷新；按Esc可暂停，窗口边缘可拖动调整尺寸。
击杀精英或首领会自动弹出转盘奖励并暂停战斗：点击跳过动画，
再次点击关闭奖励继续战斗；长文说明可以滚动阅读。
'''

assert not ARCHIVE.exists(), 'Do not overwrite an existing shareable release'
with zipfile.ZipFile(ARCHIVE, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for delivered, original in mapping.items():
        with (RUNTIME / original).open('rb') as handle:
            assert hashlib.file_digest(handle, 'sha256').hexdigest() == expected[original]
        archive.write(RUNTIME / original, delivered)
    archive.writestr('运行说明.txt', instructions.encode('utf-8'))

members = []
with zipfile.ZipFile(ARCHIVE) as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == set(mapping) | {'运行说明.txt'}
    assert archive.read('运行说明.txt').decode('utf-8') == instructions
    for delivered, original in mapping.items():
        with archive.open(delivered) as handle:
            sha = hashlib.file_digest(handle, 'sha256').hexdigest()
        assert sha == expected[original]
        members.append({'path': delivered, 'bytes': archive.getinfo(delivered).file_size, 'sha256': sha})
    with tempfile.TemporaryDirectory(prefix='T8-share-extracted-') as folder:
        clean = Path(folder)
        archive.extractall(clean)
        result = subprocess.run([str(clean / '启动游戏.exe'), '--headless', '--quit-after', '10', '--log-file', str(HERE / 'share-engine.log')], cwd=clean, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
        (HERE / 'share-startup.log').write_bytes(result.stdout)
        logs = result.stdout.decode('utf-8') + (HERE / 'share-engine.log').read_text(encoding='utf-8')
        assert result.returncode == 0 and 'SCRIPT ERROR:' not in logs and 'ERROR:' not in logs, (result.returncode, logs)

with ARCHIVE.open('rb') as handle:
    archive_hash = hashlib.file_digest(handle, 'sha256').hexdigest()
report = {'archive': str(ARCHIVE), 'bytes': ARCHIVE.stat().st_size, 'sha256': archive_hash, 'crc': 'passed', 'files': members, 'readme_utf8': True, 'extracted_startup_exit_code': result.returncode, 'source_combined_sha256': manifest['source_combined_sha256']}
(HERE / 'share-archive.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
