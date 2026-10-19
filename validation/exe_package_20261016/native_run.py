"""Launch the actual final EXE with only its PCK in a clean temporary folder."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import tempfile
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]

with tempfile.TemporaryDirectory(prefix='T8-demo-16-native-') as folder:
    clean = Path(folder)
    with zipfile.ZipFile(ROOT / 'build/守城战斗试玩-Windows-20261016.zip') as archive:
        assert archive.testzip() is None
        assert set(archive.namelist()) == {'启动游戏.exe', '启动游戏.pck', '运行说明.txt'}
        archive.extractall(clean)
    artifacts = []
    for name, delivered in [('defense-demo.exe', '启动游戏.exe'), ('defense-demo.pck', '启动游戏.pck')]:
        src = ROOT / 'build/windows' / name
        dst = clean / delivered
        sha = hashlib.file_digest(src.open('rb'), 'sha256').hexdigest()
        assert hashlib.file_digest(dst.open('rb'), 'sha256').hexdigest() == sha
        artifacts.append({'name': delivered, 'sha256': sha})
    assert len(list(clean.iterdir())) == 3
    command = [str(clean / '启动游戏.exe'), '--resolution', '480x960', '--log-file', str(HERE / 'native-engine.log')]
    with (HERE / 'native-stdout.log').open('wb') as log:
        proc = subprocess.Popen(command, cwd=clean, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        (HERE / 'native-launch.json').write_text(json.dumps({'pid': proc.pid, 'folder': str(clean), 'artifacts': artifacts}, indent=2) + '\n', encoding='utf-8', newline='\n')
        print(json.dumps({'pid': proc.pid, 'folder': str(clean)}), flush=True)
        try:
            code = proc.wait(timeout=300)
        except subprocess.TimeoutExpired:
            proc.terminate()
            proc.wait(timeout=15)
            raise
    text = (HERE / 'native-stdout.log').read_text(encoding='utf-8') + (HERE / 'native-engine.log').read_text(encoding='utf-8')
    errors = [line for line in text.splitlines() if 'SCRIPT ERROR:' in line or 'ERROR:' in line]
    result = {'exit_code': code, 'errors': errors, 'clean_directory': True, 'initial_files': artifacts}
    (HERE / 'native-process.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    assert code == 0 and not errors, result
    print(json.dumps(result), flush=True)
