"""Check native fire center measurements and assemble unchanged frame previews."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation/defense/fire_centers"
LABELS = {"ordinary": "火球 · 命中后目标向右移走", "pyro": "炎爆 · 三次命中各自固定中心"}


def tile(name: str, at: int) -> Image.Image:
    source = Image.open(OUT / "frames" / f"{name}_{at:04d}.png").convert("RGB")
    assert source.size == (720, 1440), (name, at, source.size)
    result = Image.new("RGB", (600, 1032), "#18271b")
    result.paste(source.crop((120, 120, 720, 1120)), (0, 32))
    font = ImageFont.truetype(str(ROOT / "assets/runtime/defense/chinese.ttf"), 20)
    ImageDraw.Draw(result).text((12, 4), f"{LABELS[name]}  {at}ms", font=font, fill="white")
    return result


def main():
    data = json.loads((OUT / "center_measurements.json").read_text(encoding="utf-8"))
    summary = {"cases": {}, "source_sha256": {}}
    for case in data:
        name = case["case"]
        anchors = {hit["target"]: hit["position"] for hit in case["impacts"]}
        assert len(anchors) == (3 if name == "pyro" else 1)
        phases = {target: set() for target in anchors}
        effect_ids = set()
        for frame in case["frames"]:
            for p in frame["effects"]:
                assert p["position"] == anchors[p["target"]], (name, frame["time_ms"], p)
                assert p["radius"] == (351 if p["phase"] == "secondary" else 270)
                phases[p["target"]].add(p["phase"])
                effect_ids.add(p["id"])
        assert all(kinds == {"main", "secondary", "ember"} for kinds in phases.values())
        assert len(effect_ids) == len(anchors) * 3
        assert case["target_moved"]
        first_target = case["frames"][-1]["targets"][0]
        assert first_target["position"] != anchors[first_target["id"]]
        frames = [tile(name, frame["time_ms"]) for frame in case["frames"]]
        frames[0].save(OUT / f"{name}.gif", save_all=True, append_images=frames[1:],
                       duration=128, loop=0, optimize=True)
        summary["cases"][name] = {"impacts": case["impacts"], "effect_count": len(effect_ids),
                                  "frame_count": len(frames), "moved_at_ms": case["moved_at_ms"],
                                  "radius": {"main": 270, "secondary": 351, "ember": 270},
                                  "all_centers_frozen": True}
    sheet = Image.new("RGB", (1800, 1032), "#18271b")
    for i, (name, at) in enumerate([("ordinary", 384), ("pyro", 1024), ("pyro", 2048)]):
        sheet.paste(tile(name, at), (600 * i, 0))
    sheet.save(OUT / "center_review.png")
    for path in ["src/features/defense/domain/defense_fireball.gd",
                 "src/features/defense/domain/defense_projectiles.gd",
                 "src/features/defense/domain/defense_projectile_factory.gd",
                 "src/features/defense/domain/defense_projectile_motion.gd",
                 "src/features/defense/domain/defense_targets.gd",
                 "src/features/defense/domain/defense_snapshot.gd",
                 "src/features/defense/presentation/defense_field.gd",
                 "src/features/defense/presentation/defense_fire_visual.gd",
                 "tests/test_defense_fire_centers.gd", "tools/capture_fire_centers.gd"]:
        summary["source_sha256"][path] = hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
    (OUT / "center_validation.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
                                                 encoding="utf-8", newline="\n")
    print(json.dumps(summary["cases"], ensure_ascii=False, indent=2))
    print("[OK] Native fire centers, independent impact groups, radii and frozen positions")


if __name__ == "__main__":
    main()
