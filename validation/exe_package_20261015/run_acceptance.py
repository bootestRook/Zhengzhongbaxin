"""Validate this delivery against the source runtime and exported PCK."""
from pathlib import Path
import argparse
import json
import os
import subprocess

from PIL import Image, ImageChops, ImageStat, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
STAGE = Path('F:/T8demo/_package_stage/T8-demo-16-20261015')
GODOT = Path('D:/godot/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64_console.exe')


def run(label):
    output = HERE / label
    output.mkdir(exist_ok=True)
    cmd = [str(GODOT), '--fixed-fps', '60', '--resolution', '480x960', '--audio-driver', 'Dummy']
    if label == 'source':
        cmd += ['--path', str(ROOT)]
    else:
        pack = (STAGE if label == 'candidate' else ROOT) / 'build/windows/defense-demo.pck'
        cmd += ['--main-pack', str(pack)]
    cmd += ['--script', str(HERE / 'capture.gd'), '--', output.as_posix(), (HERE / 'expectations.json').as_posix()]
    env = os.environ | {'PYTHONUTF8': '1', 'PYTHONIOENCODING': 'utf-8'}
    with (HERE / f'{label}.log').open('wb') as log:
        result = subprocess.run(cmd, cwd=ROOT if label == 'source' else output, stdout=log, stderr=subprocess.STDOUT, env=env, timeout=300)
    logs = (HERE / f'{label}.log').read_text(encoding='utf-8')
    assert result.returncode == 0 and 'SCRIPT ERROR:' not in logs and 'ERROR:' not in logs, logs[-5000:]
    report = json.loads((output / 'report.json').read_text(encoding='utf-8'))
    assert not report['errors'], report
    print(label, {key: report[key] for key in ['assets_loaded', 'raw_files_verified', 'font_characters', 'missing_glyphs', 'battle']}, flush=True)
    if label != 'source':
        compare('source', label)


def compare(left, right):
    frames = []
    for path in sorted((HERE / left).glob('*.png')):
        other = HERE / right / path.name
        assert other.exists(), other
        a = Image.open(path).convert('RGB')
        b = Image.open(other).convert('RGB')
        assert a.size == b.size, path
        diff = ImageChops.difference(a, b)
        frames.append({'name': path.name, 'identical': diff.getbbox() is None, 'mean_channel_difference': sum(ImageStat.Stat(diff).mean) / 3})
    report = {'count': len(frames), 'identical': sum(row['identical'] for row in frames), 'frames': frames}
    (HERE / f'{left}-vs-{right}.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
    print('parity', right, json.dumps(report), flush=True)
    review(right)


def review(label):
    names = ['home_480x960', 'initial_choice', 'choice_tooltip', 'choice_attributes', 'battle', 'five_heroes', 'pause', 'result']
    sheet = Image.new('RGB', (4 * 240, 2 * 505), '#252525')
    draw = ImageDraw.Draw(sheet)
    for index, name in enumerate(names):
        p = HERE / label / (name + '.png')
        if not p.exists():
            continue
        image = Image.open(p).convert('RGB')
        image.thumbnail((240, 480))
        x, y = index % 4 * 240, index // 4 * 505
        sheet.paste(image, (x, y + 22))
        draw.text((x + 4, y + 3), name, fill='white')
    sheet.save(HERE / f'{label}-review.jpg', quality=90)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['source', 'candidate', 'final', 'review'])
    args = parser.parse_args()
    if args.mode == 'review':
        review('source')
    else:
        run(args.mode)
