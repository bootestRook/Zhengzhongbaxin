"""Exercise the actual double-click entry point without Excel installed."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]
WORK = Path(__file__).resolve().parent
OUTPUT = ROOT / 'data/generated/defense_catalog.json'
environment = os.environ.copy()
environment.update(PYTHONUTF8='1', PYTHONIOENCODING='utf-8', T8_TABLE_NO_PAUSE='1')
records = []
with tempfile.TemporaryDirectory(prefix='t8_export_') as temporary:
    cwd = Path(temporary) / '中文 目录'
    cwd.mkdir()
    for label, extra, expected in [('bat_success', [], 0), ('bat_failure', ['--tables-dir', str(cwd/'missing')], 1)]:
        previous = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
        start = time.monotonic()
        result = subprocess.run(['cmd.exe', '/d', '/c', str(ROOT/'导表.bat'), *extra], cwd=cwd, env=environment, capture_output=True)
        text = (result.stdout+result.stderr).decode('utf-8')
        (WORK/f'{label}.log').write_text(text, encoding='utf-8', newline='\n')
        assert result.returncode == expected, (label, result.returncode, text)
        assert not any(marker in text for marker in ['SCRIPT ERROR:', 'TEST FAILURE:']), text
        if expected:
            assert hashlib.sha256(OUTPUT.read_bytes()).hexdigest() == previous
        records.append({'case': label, 'exit': result.returncode, 'seconds': round(time.monotonic()-start, 3)})
        print(label, 'passed')
catalog = json.loads(OUTPUT.read_text(encoding='utf-8'))
assert all(catalog['skills'][key]['description'] for key in ['755','17','20301','20002','1435'])
assert catalog['monsters']['101']['title'] == '小鼠'
assert '基础怪物' in catalog['monsters']['101']['description']
assert len([key for key in catalog['source_hashes'] if key.endswith('.xlsx')]) == 7
(WORK/'export_checks.json').write_text(json.dumps(records, ensure_ascii=False, indent=2)+'\n', encoding='utf-8', newline='\n')
print('Runtime JSON contains descriptions, Chinese monster text and seven workbook hashes.')
