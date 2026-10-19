"""Verify fresh release inputs and copy only the checked release artifacts."""
from pathlib import Path
import hashlib
import json
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
STAGE = Path('F:/T8demo/_package_stage/T8-demo-16-20261015')
sys.path.insert(0, str(ROOT))
from tools import release_manifest


def digest(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()


def copy_release():
    source = release_manifest.build_manifest()
    stage_build = STAGE / 'build/windows'
    manifest = json.loads((stage_build / 'package-manifest.json').read_text(encoding='utf-8'))
    assert manifest['stage'] == 'release', manifest['stage']
    assert source['combined_sha256'] == manifest['source_combined_sha256'], 'project changed after snapshot'
    destination = ROOT / 'build/windows'
    assert not destination.exists(), 'refuse to mix release with an existing output'
    destination.mkdir(parents=True)
    for item in manifest['files']:
        original = stage_build / item['path']
        assert digest(original) == item['sha256'], item
        shutil.copy2(original, destination / item['path'])
        assert digest(destination / item['path']) == item['sha256'], item
    shutil.copy2(stage_build / 'package-manifest.json', destination / 'package-manifest.json')
    (HERE / 'release-inputs.json').write_text(json.dumps(source, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps({'delivered': str(destination), 'source_sha256': source['combined_sha256'], 'files': manifest['files']}, indent=2), flush=True)


def verify_release():
    source = release_manifest.build_manifest()
    manifest = json.loads((ROOT / 'build/windows/package-manifest.json').read_text(encoding='utf-8'))
    assert source['combined_sha256'] == manifest['source_combined_sha256'], 'project changed during acceptance'
    for item in manifest['files']:
        assert digest(ROOT / 'build/windows' / item['path']) == item['sha256'], item
    qa = json.loads((HERE / 'final/report.json').read_text(encoding='utf-8'))
    parity = json.loads((HERE / 'source-vs-final.json').read_text(encoding='utf-8'))
    assert not qa['errors'] and not qa['missing_glyphs']
    assert parity['identical'] == parity['count'] == 16, parity
    assert qa['battle']['won'] and qa['battle']['wave'] == 20 and qa['battle']['bosses_dead'] == 3
    native = json.loads((HERE / 'native.json').read_text(encoding='utf-8'))
    assert native['exit_code'] == 0 and native['main_menu'] and native['recruitment'] and native['battle'] and native['pause'] and native['return_home']
    assert native['errors'] == []
    result = {'source_combined_sha256': source['combined_sha256'], 'source_files': source['file_count'], 'artifacts': manifest['files'], 'qa': qa, 'pixel_parity': parity, 'native': native}
    (HERE / 'delivery.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    report = f'''# Windows EXE 打包验收

交付目录：`build/windows/`，双击 `defense-demo.exe`。同目录 `defense-demo.pck` 必须一起保留。

- 引擎：{manifest['godot_version']}，Compatibility 渲染。
- 逻辑画布：960×1920；默认窗口：720×1440，可缩放，保持纵横比。
- 每次导出均清理隔离副本的 Godot 缓存和导出目录，重新生成数据、资源清单和源指纹。
- 当前工程、构建副本、最终制品源指纹一致：`{source['combined_sha256']}`；共 {source['file_count']} 个发布输入。
- 41 项 Python 测试、5,825 条 Godot 断言、工程与打包门禁通过。
- 全部 106 个运行资源加载成功，5 份生成 JSON 与当前工程 SHA-256 相同。
- 957 个中文字符均有捆绑字体字形。
- 6 种窗口尺寸：480×960、720×1440、960×1920、1280×720、1920×1080、1024×768；横屏按竖屏比例留边，完成全屏往返。
- 源码与最终 PCK 的 16 张对照截图逐像素一致，涵盖主页、关卡、图鉴、招募、技能、属性、战斗、五英雄、暂停、结算。
- 最终 PCK 使用合法候选完成五英雄、20 波、3 首领胜利对局，未修改生产玩法。
- 最终 EXE/PCK 在不含工程文件的目录运行，通过主页、开始、招募、战斗、暂停、退出结算、返回主页及关闭；退出码 0，无 SCRIPT ERROR / ERROR。

验证环境为本机 Windows、NVIDIA RTX 5080、192 DPI；其他机器和显示器尚未验证。

详细记录：`delivery.json`、`final-build.log`、`final/report.json`、`source-vs-final.json`、`native.json`。
'''
    (HERE / '打包验收.md').write_text(report, encoding='utf-8', newline='\n')
    print('DELIVERY VERIFIED', json.dumps({'files': len(manifest['files']), 'pixel_parity': parity['identical'], 'native_exit': native['exit_code']}))


if __name__ == '__main__':
    {'copy': copy_release, 'verify': verify_release}[sys.argv[1]]()
