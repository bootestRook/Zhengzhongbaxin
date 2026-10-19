"""Verify captured flight displacements and assemble previews from native frames."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation/defense/projectiles"
EXPECTED = {"ice3": [0, -7, 7], "ice4": [0, -7, 7, -14],
            "fire1": [0], "fire2": [0, -5], "fire3": [0, -5, 5]}
LABELS = {"ice3": "寒冰三箭 · 7°", "ice4": "寒冰齐射四箭 · 7°",
          "fire1": "单颗火球", "fire2": "双火球 · 5°", "fire3": "三火球 · 5°",
          "pyro": "炎爆穿透三人", "refraction": "穿透与折射"}


def relative_angle(reference, vector):
    return math.degrees(math.atan2(reference[0] * vector[1] - reference[1] * vector[0],
                                   reference[0] * vector[0] + reference[1] * vector[1]))


def tile(label: str, at: int) -> Image.Image:
    source = Image.open(OUT / "frames" / f"{label}_{at:04d}.png").convert("RGB")
    assert source.size == (720, 1440), (label, at, source.size)
    result = Image.new("RGB", (460, 920), "#18271b")
    result.paste(source.crop((130, 150, 590, 1040)), (0, 30))
    font = ImageFont.truetype(str(ROOT / "assets/runtime/defense/chinese.ttf"), 20)
    ImageDraw.Draw(result).text((12, 4), LABELS[label], font=font, fill="white")
    return result


def main():
    data = json.loads((OUT / "flight_measurements.json").read_text(encoding="utf-8"))
    by_name = {case["case"]: case for case in data}
    summary = {"cases": {}, "native_sizes": [], "source_sha256": {}}
    for name, expected in EXPECTED.items():
        case = by_name[name]
        assert case["initial_count"] == len(expected)
        assert all(abs(a - b) < 0.001 for a, b in zip(case["initial_degrees"], expected, strict=True))
        first = case["frames"][0]["missiles"]
        actual = []
        for missile in first:
            points = [p["position"] for frame in case["frames"] for p in frame["missiles"]
                      if p["id"] == missile["id"]]
            vector = [points[-1][i] - points[0][i] for i in range(2)]
            actual.append(relative_angle(first[0]["direction"], vector))
        assert all(abs(a - b) < 0.01 for a, b in zip(actual, expected, strict=True)), (name, actual)
        summary["cases"][name] = {"count": len(expected), "direction_degrees": case["initial_degrees"],
                                   "measured_displacement_degrees": actual}
    for name in ["ice4", "fire3"]:
        for width in [960, 720, 540]:
            size = Image.open(OUT / f"{name}_{width}.png").size
            assert size == (width, width * 2), (name, width, size)
            summary["native_sizes"].append({"case": name, "width": size[0], "height": size[1]})
    for name in LABELS:
        frames = [tile(name, f["time_ms"]) for f in by_name[name]["frames"]]
        frames[0].save(OUT / f"{name}.gif", save_all=True, append_images=frames[1:],
                       duration=128, loop=0, optimize=True)
    pairs = []
    for at in range(0, 641, 64):
        page = Image.new("RGB", (920, 920), "#18271b")
        page.paste(tile("ice4", at), (0, 0))
        page.paste(tile("fire3", at), (460, 0))
        pairs.append(page)
    pairs[0].save(OUT / "spread_comparison.gif", save_all=True, append_images=pairs[1:],
                  duration=128, loop=0, optimize=True)
    sheet = Image.new("RGB", (1840, 920), "#18271b")
    for i, name in enumerate(["ice3", "ice4", "fire2", "fire3"]):
        sheet.paste(tile(name, 384), (460 * i, 0))
    sheet.save(OUT / "spread_comparison.png")
    contact = Image.new("RGB", (1840, 920), "#18271b")
    for i, (name, at) in enumerate([("pyro", 320), ("pyro", 640), ("refraction", 320), ("refraction", 640)]):
        contact.paste(tile(name, at), (460 * i, 0))
    contact.save(OUT / "contact_review.png")
    for path in ["data/source/defense_tables/02_英雄技能.xlsx", "data/generated/defense_catalog.json",
                 "src/features/defense/domain/defense_ice_arrows.gd", "src/features/defense/domain/defense_fireball.gd",
                 "src/features/defense/domain/defense_projectile_factory.gd", "src/features/defense/domain/defense_projectile_motion.gd",
                 "src/features/defense/domain/defense_projectile_geometry.gd", "src/features/defense/domain/defense_projectiles.gd",
                 "src/features/defense/domain/defense_snapshot.gd"]:
        summary["source_sha256"][path] = hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
    (OUT / "flight_validation.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(summary["cases"], ensure_ascii=False, indent=2))
    print("[OK] Native dimensions, emitted counts, actual displacement angles and previews")


if __name__ == "__main__":
    main()
