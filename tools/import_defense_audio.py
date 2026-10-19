"""Freeze the supplied current-client sound files and their deterministic name index."""
from pathlib import Path
import csv
import hashlib
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('F:/T8demo/正中靶心2_拆解_20261013/09_当前客户端补充/02_音频资源')

def main(source_dir=SOURCE):
    dest = ROOT / 'assets/runtime/defense/audio'
    dest.mkdir(parents=True, exist_ok=True)
    archive_path = ROOT / 'art_source/defense/original_audio.zip'
    index = {}
    hashes = {}
    with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED) as archive:
        for source in sorted(source_dir.iterdir()):
            if source.suffix.lower() not in ['.mp3', '.wav', '.ogg']:
                continue
            content = source.read_bytes()
            digest = hashlib.sha256(content).hexdigest()
            name = source.stem.split('__')[0]
            target = dest / (name + '_' + digest[:12] + source.suffix)
            if not target.exists():
                shutil.copy2(source, target)
            uri = 'res://' + target.relative_to(ROOT).as_posix()
            if uri not in index.setdefault(name, []):
                index[name].append(uri)
            hashes[source.name] = digest
            info = zipfile.ZipInfo(source.name, date_time=(2026, 10, 13, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, content)
    path = ROOT / 'data/source/defense/art.json'
    art = json.loads(path.read_text(encoding='utf-8'))
    art['audio'] = index
    path.write_text(json.dumps(art,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8',newline='\n')
    (ROOT / 'art_source/defense/audio_provenance.json').write_text(json.dumps(hashes,indent=2)+'\n',encoding='utf-8',newline='\n')
    binding = ROOT / 'data/source/resource_bindings.csv'
    with binding.open(encoding='utf-8',newline='') as file:
        reader=csv.DictReader(file);fields=reader.fieldnames;rows=[r for r in reader if not r['id'].startswith('defense.audio.')]
    for i, uri in enumerate(sorted({uri for files in index.values() for uri in files})):
        rows.append(dict(zip(fields,[f'defense.audio.{i}','audio','art_source/defense/original_audio.zip',uri,'defense_audio','defense_art','project_research','third_party','true','defense'])))
    with binding.open('w',encoding='utf-8',newline='') as file:
        writer=csv.DictWriter(file,fields,lineterminator='\n');writer.writeheader();writer.writerows(rows)
    print(f'[OK] imported {len(hashes)} sound files, {len(index)} semantic names')

if __name__ == '__main__':
    main()
