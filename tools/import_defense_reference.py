"""Freeze user-provided reference tables and pack their PNG frames, without source code."""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import math
import re
import shutil
import zipfile
from pathlib import Path
from PIL import Image, PngImagePlugin
from defense_reference_icons import register_icons

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = Path(r"F:\T8demo\正中靶心2_拆解_20261013")
PACKAGES = {f"hero{i}" for i in range(1, 19)} | {
    "enemy", "enemy2", "enemyM1", "enemyM2", "enemyM3", "battleEffect",
    "bullet", "bullet2", "bulletStatus", "map", "home", "battle", "common",
    "gameIcon", "statue", "role", "font", "atlas",
}
UI_SPRITES = {("gem", "mpt"), ("gem", "5_0")}
# These source names identify distinct items. Keep their item IDs in the key
# even if a later export removes one variant; CSV order must never select art.
VARIANT_NAMES = {"common:talentPointReward", "common:bg3", "map:circular"}


def write_json(path: Path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8", newline="\n")


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def freeze_tables(source: Path):
    base = source / "06_战斗逻辑/当前版本"
    names = ["lead", "attribute", "skill2", "upgrade_options", "status2", "target2",
             "monster", "entity", "skill_icon", "skill_attribute", "wall", "wall_skill",
             "level_buff", "chapter", "enemyLevel", "equip_skill", "function_price"]
    tables = {}
    provenance = []
    for name in names:
        path = base / "配置全表" / f"{name}.json"
        if not path.exists():
            continue
        tables[name] = read_json(path)
        provenance.append({"table": name, "source": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    text = read_json(base / "中文文本原表.json")
    tables["chinese"] = {key: {k: v.get("cn2") or v.get("cn", "") for k, v in rows.items()} for key, rows in text.items()}
    tables["waves"] = [row for row in read_json(base / "逐关逐波输入.json") if 1 <= row["level"] <= 50]
    tables["level_details"] = read_json(source / "10_复刻前研究_20261013/前50关配置明细.json")
    tables["schema_version"] = 1
    tables["provenance"] = provenance
    write_json(ROOT / "data/source/defense/reference.json", tables)


class Atlas:
    def __init__(self):
        self.page = Image.new("RGBA", (4096, 4096))
        self.x = self.y = self.row_height = 2
        self.index = 0
        self.pages = []
        self.sprites = {}
        self.seen = {}

    def flush(self):
        if not self.sprites:
            return
        rel = f"assets/runtime/defense/atlas_{self.index:02d}.png"
        path = ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        info = PngImagePlugin.PngInfo()
        info.add_text("Source", "User-provided current client PNG frames; provenance: art_source/defense/original_pngs.zip")
        info.add_text("impeccable:prompt", "Sourced existing user-provided current client PNG frames, not AI generated. Origin: art_source/defense/original_pngs.zip; source and runtime hashes: art_source/defense/provenance.json.")
        temporary = path.with_suffix(".png.tmp")
        self.page.crop((0, 0, 4096, min(4096, self.y + self.row_height + 2))).save(temporary, format="PNG", pnginfo=info)
        temporary.replace(path)
        self.pages.append(rel)
        self.index += 1
        self.page = Image.new("RGBA", (4096, 4096))
        self.x = self.y = self.row_height = 2

    def add(self, key: str, path: Path):
        if key in self.sprites:
            raise ValueError(f"duplicate source sprite name {key}")
        im = Image.open(path).convert("RGBA")
        width, height = im.size
        box = im.getbbox()
        if box is None:
            self.sprites[key] = {"blank": True, "size": [width, height]}
            return
        tile = im.crop(box)
        digest = hashlib.sha256(tile.tobytes() + str(tile.size).encode()).hexdigest()
        if digest in self.seen:
            data = self.seen[digest].copy()
        else:
            w, h = tile.size
            if max(w, h) > 4092:
                raise ValueError(f"oversized source sprite {key}: {tile.size}")
            if self.x + w + 2 > 4096:
                self.x = 2
                self.y += self.row_height + 2
                self.row_height = 2
            if self.y + h + 2 > 4096:
                self.flush()
            self.page.paste(tile, (self.x, self.y))
            data = {"page": self.index, "rect": [self.x, self.y, w, h]}
            self.seen[digest] = data.copy()
            self.x += w + 2
            self.row_height = max(self.row_height, h)
        data.update({"size": [width, height], "offset": [box[0], box[1]]})
        self.sprites[key] = data


def import_assets(source: Path):
    source = source / "09_当前客户端补充"
    dest = ROOT / "assets/runtime/defense"
    dest.mkdir(parents=True, exist_ok=True)
    art = ROOT / "art_source/defense"
    art.mkdir(parents=True, exist_ok=True)
    atlas = Atlas()
    animations = {}
    originals = set()
    for row in read_json(source / "01_动作索引.json"):
        if row["package"] not in PACKAGES:
            continue
        animation = read_json(source / row["output"])
        key = row["package"] + ":" + row["name"]
        frames = []
        for index, frame in enumerate(animation["frames"]):
            sprite = f"{key}@{index}"
            file = source / frame["output"]
            if file.is_file():
                atlas.add(sprite, file)
                originals.add(file)
            else:
                atlas.sprites[sprite] = {"blank": True, "size": [animation["width"], animation["height"]]}
            frames.append({"sprite": sprite, "duration_ms": round(float(frame.get("duration", animation["interval_seconds"])) * 1000)})
        animations[key] = {"size": [animation["width"], animation["height"]], "frames": frames,
                           "swing": animation["swing"], "repeat_delay_ms": round(animation["repeat_delay_seconds"] * 1000)}
    with (source / "01_FairyGUI子图索引.csv").open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            if row["package"] not in PACKAGES and (row["package"], row["item_name"]) not in UI_SPRITES:
                continue
            file = source / row["output"]
            if file.is_file():
                key = row["package"] + ":" + row["item_name"]
                if key in VARIANT_NAMES:
                    key += "__" + row["item_id"]
                atlas.add(key, file)
                originals.add(file)
    atlas.flush()
    font = next((source / "01_美术资源/07_字体").glob("AlibabaPuHuiTi*.ttf"))
    shutil.copy2(font, dest / "chinese.ttf")
    originals.add(font)
    # Keep original edit inputs outside ResourceFS, with stable archive member names.
    with zipfile.ZipFile(art / "original_pngs.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(originals):
            info = zipfile.ZipInfo(path.relative_to(source).as_posix(), date_time=(2026, 10, 13, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())
    asset_data = {"schema_version": 1, "pages": ["res://" + p for p in atlas.pages],
                  "sprites": atlas.sprites, "animations": animations, "font": "res://assets/runtime/defense/chinese.ttf"}
    previous = ROOT / "data/source/defense/art.json"
    if previous.is_file() and "audio" in read_json(previous):
        asset_data["audio"] = read_json(previous)["audio"]
    register_icons(asset_data)
    write_json(ROOT / "data/source/defense/art.json", asset_data)
    write_json(art / "provenance.json", {"origin": str(source), "source_count": len(originals),
               "archive_sha256": hashlib.sha256((art / "original_pngs.zip").read_bytes()).hexdigest(),
               "runtime_sha256": {p[6:]: hashlib.sha256((ROOT / p[6:]).read_bytes()).hexdigest() for p in asset_data["pages"]}})
    binding = ROOT / "data/source/resource_bindings.csv"
    with binding.open(encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file); fields = reader.fieldnames
        rows = [row for row in reader if not row["id"].startswith("defense.atlas.") and row["id"] != "defense.font"]
    for index, page in enumerate(atlas.pages):
        rows.append(dict(zip(fields, [f"defense.atlas.{index}", "texture_2d", "art_source/defense/original_pngs.zip", "res://" + page,
                   "defense_atlas", "defense_art", "project_research", "third_party", "true", "defense"])))
    rows.append(dict(zip(fields, ["defense.font", "font", "art_source/defense/original_pngs.zip", "res://assets/runtime/defense/chinese.ttf",
                "font_runtime", "defense_art", "project_research", "third_party", "true", "defense"])))
    with binding.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fields, lineterminator="\n");writer.writeheader();writer.writerows(rows)
    print(f"Imported {len(animations)} animations, {len(atlas.sprites)} sprites, {len(atlas.pages)} atlas pages")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT)
    parser.add_argument("--tables-only", action="store_true")
    args = parser.parse_args()
    freeze_tables(args.source)
    if not args.tables_only:
        import_assets(args.source)
        from import_defense_audio import main as import_audio
        import_audio(args.source / "09_当前客户端补充/02_音频资源")
    from import_defense_combat import build as import_combat
    import_combat(args.source)
