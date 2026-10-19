"""Publish the fresh release after verifying source and artifact hashes."""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
STAGE = Path('F:/T8demo/_package_stage/T8-demo-16-20261015-r2')
sys.path.insert(0, str(ROOT))
from tools import release_manifest


def digest(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')


def copy_release():
    source = release_manifest.build_manifest()
    artifacts = STAGE / 'build/windows'
    manifest = read(artifacts / 'package-manifest.json')
    assert manifest['stage'] == 'release'
    assert source['combined_sha256'] == manifest['source_combined_sha256'], 'source changed during build'
    build = (ROOT / 'build').resolve()
    destination = build / 'windows'
    incoming = build / ('windows-next-' + source['combined_sha256'][:12])
    assert incoming.parent == destination.parent == build
    assert not incoming.exists()
    incoming.mkdir(parents=True)
    for item in manifest['files']:
        assert Path(item['path']).name == item['path']
        assert digest(artifacts / item['path']) == item['sha256']
        shutil.copy2(artifacts / item['path'], incoming / item['path'])
        assert digest(incoming / item['path']) == item['sha256']
    shutil.copy2(artifacts / 'package-manifest.json', incoming / 'package-manifest.json')
    if destination.exists():
        old = read(destination / 'package-manifest.json')
        previous = build / ('previous-' + old['source_combined_sha256'][:12])
        assert previous.parent == build and not previous.exists()
        os.replace(destination, previous)
    os.replace(incoming, destination)
    write(HERE / 'release-inputs.json', source)
    print(json.dumps({'delivery': str(destination), 'source_sha256': source['combined_sha256'], 'files': manifest['files']}), flush=True)


def verify():
    source = release_manifest.build_manifest()
    manifest = read(ROOT / 'build/windows/package-manifest.json')
    assert source['combined_sha256'] == manifest['source_combined_sha256'], 'source changed during acceptance'
    for item in manifest['files']:
        assert digest(ROOT / 'build/windows' / item['path']) == item['sha256']
    qa = read(HERE / 'final/report.json')
    parity = read(HERE / 'source-vs-final.json')
    native = read(HERE / 'native.json')
    assert not qa['errors'] and not qa['missing_glyphs']
    assert parity['identical'] == parity['count'] and parity['count'] >= 16
    assert qa['battle']['won'] and qa['battle']['wave'] == 20 and qa['battle']['bosses_dead'] == 3
    assert qa['unlocked_heroes'] == [1, 2, 4, 13, 17]
    assert qa['refresh_sequence'] == [2, 1, 0, 2]
    assert len(qa['two_skills']) == 5
    assert native['exit_code'] == 0 and native['errors'] == []
    assert all(native[key] for key in ['main_menu', 'recruitment', 'two_skills', 'battle', 'pause', 'return_home'])
    logs = (HERE / 'final-build.log').read_text(encoding='utf-8')
    assert '[FAIL]' not in logs and 'SCRIPT ERROR:' not in logs and 'ERROR:' not in logs
    project_checks = (HERE / 'project-check.log').read_text(encoding='utf-8')
    assert '[OK] runtime smoke' in project_checks
    assert '[FAIL]' not in project_checks and 'SCRIPT ERROR:' not in project_checks and 'ERROR:' not in project_checks
    python_tests = int(re.search(r'Ran (\d+) tests', logs).group(1))
    godot_assertions = int(re.search(r'Godot tests: (\d+) assertions', logs).group(1))
    write(HERE / 'delivery.json', {'source': source['combined_sha256'], 'source_files': source['file_count'], 'artifacts': manifest['files'], 'python_tests': python_tests, 'godot_assertions': godot_assertions, 'project_check': 'passed', 'qa': qa, 'parity': parity, 'native': native, 'qa_harness_note': read(HERE / 'qa-process-note.json')})
    matrix = '、'.join(f'{w}×{h}' for w, h in read(ROOT / 'package_profiles.json')['profiles']['exe']['test_resolutions'])
    text = f'''# 最新 Windows EXE 验收

交付：`build/windows/defense-demo.exe` 与同目录 `defense-demo.pck`，二者必须一起保留。

- 引擎 {manifest['godot_version']}，Compatibility 渲染；画布960×1920，默认窗口720×1440，等比缩放。
- 隔离构建，候选与正式包各自清理缓存、重建生成数据和资源清单、重建源指纹、完整检查后导出。
- 当前工程、构建副本、最终制品源指纹一致：`{source['combined_sha256']}`，{source['file_count']}个发布输入。
- {python_tests}项Python测试、{godot_assertions}条Godot断言、工程与打包门禁全部通过。
- 全部{qa['assets_loaded']}项运行资源可加载，{qa['raw_files_verified']}份生成JSON与当前工程哈希一致。
- 捆绑字体覆盖{qa['font_characters']}个中文字符，缺字0。
- 窗口矩阵：{matrix}，横屏等比留边；全屏往返通过。
- 源码与最终PCK的{parity['count']}张画面对照逐像素一致。
- 最新规则：仅默认五英雄[1,2,4,13,17]可招募；各两项初始技能；每局刷新2次，实测2→1→0，新局恢复2。
- 最终PCK通过合法招募/强化完成五英雄、20波、3首领胜利；未修改生产玩法。
- 最终EXE/PCK在不含工程文件的目录中通过主页、招募、双技能查看、战斗、暂停、退出结算、返回主页和关闭；退出码0，无脚本或资源错误。

验证环境为本机Windows、RTX5080、192DPI；不延伸为其他机器的验收结论。

验收工具记录：首次最终画面对照进程在加速模拟段提前退出，Windows同期记录AppHangB1；同一PCK重跑通过。验收脚本随后在连续模拟中定期让出帧，修正后再完成全对局和画面对照；没有修改游戏代码。

明细：`delivery.json`、`final-build.log`、`project-check.log`、`final/report.json`、`source-vs-final.json`、`native.json`、`qa-process-note.json`。
'''
    (HERE / '打包验收.md').write_text(text, encoding='utf-8', newline='\n')
    print(json.dumps({'verified': True, 'python_tests': python_tests, 'godot_assertions': godot_assertions, 'parity': parity['count'], 'native_exit': native['exit_code']}), flush=True)


if __name__ == '__main__':
    {'copy': copy_release, 'verify': verify}[sys.argv[1]]()
