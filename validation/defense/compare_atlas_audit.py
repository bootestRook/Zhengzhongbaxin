"""Compare every real UI capture before/after in-memory atlas relocation."""
from pathlib import Path
import json

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT / "validation/defense/atlas_audit"


def main():
    results = []
    for path in sorted(DIRECTORY.glob("*_original.png")):
        target = path.with_name(path.name.replace("_original.png", "_repacked.png"))
        with Image.open(path) as source, Image.open(target) as repacked:
            if source.size != repacked.size:
                raise ValueError(f"viewport dimensions changed: {path.stem}")
            delta = ImageChops.difference(source.convert("RGB"), repacked.convert("RGB"))
            histogram = delta.histogram()
            pixels = source.width * source.height
            mean = sum((i % 256) * count for i, count in enumerate(histogram)) / (pixels * 3)
            channels = delta.split()
            maximum = ImageChops.lighter(ImageChops.lighter(channels[0], channels[1]), channels[2])
            significant = sum(maximum.histogram()[3:])
            results.append({"capture": path.stem.replace("_original", ""), "mean_channel_error": mean,
                            "pixels_over_2": significant, "pixel_count": pixels,
                            "passed": mean <= 0.05 and significant / pixels <= 0.0001})
    if len(results) != 78:
        raise ValueError(f"expected 26 UI states at 3 sizes, found {len(results)}")
    report = {"relocation": "all 15 pages reversed, actual pixels padded by 8px, all sprite regions relocated; page dimensions changed",
              "tolerance": "mean RGB error <= 0.05 and <= 0.01% pixels exceeding 2 channel values",
              "passed": all(item["passed"] for item in results), "comparisons": results}
    (DIRECTORY / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    paths = sorted(DIRECTORY.glob("*_720_repacked.png"))
    sheet = Image.new("RGB", (6 * 190, ((len(paths) + 5) // 6) * 407), "#22252a")
    draw = ImageDraw.Draw(sheet)
    for index, path in enumerate(paths):
        with Image.open(path) as image:
            image.thumbnail((180, 360))
            x, y = index % 6 * 190 + 5, index // 6 * 407 + 35
            sheet.paste(image, (x, y))
            draw.text((x, y - 27), path.stem.replace("_720_repacked", ""), fill="white")
    sheet.save(DIRECTORY / "contact.png")
    failures = [item for item in results if not item["passed"]]
    print(f"[ATLAS AUDIT] {len(results)} comparisons; {len(failures)} failures; maximum mean error={max(item['mean_channel_error'] for item in results):.6f}")
    for item in failures:
        print(item)
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
