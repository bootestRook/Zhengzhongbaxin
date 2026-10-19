"""Build named screenshot icons using the existing defense sprite-index format."""
from pathlib import Path
import hashlib
import json

from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[1]
PAGE = "res://assets/runtime/defense/home_reference_icons.png"
ICONS = {
    "homeReference:energy": (817, 86, 858, 127),
    "homeReference:diamond": (812, 140, 861, 179),
    "homeReference:coin": (815, 189, 856, 227),
    "homeReference:activity": (94, 265, 193, 364),
    "homeReference:firstGift": (98, 465, 196, 537),
    "homeReference:territory": (827, 1357, 947, 1502),
    "homeReference:avatar": (89, 104, 177, 188),
}
RESULT_CRYSTAL = (403, 1358, 465, 1421)
RESULT_EQUIPMENT = (712, 1340, 809, 1438)


def register_icons(art, root=ROOT):
    source = root / "art_source/defense/home_reference.png"
    with Image.open(source) as image:
        reference = image.convert("RGBA")
    sheet = Image.new("RGBA", (768, 768))
    if PAGE not in art["pages"]:
        art["pages"].append(PAGE)
    page = art["pages"].index(PAGE)
    for index, (key, region) in enumerate(ICONS.items()):
        icon = reference.crop(region)
        pixels = icon.load()
        for y in range(icon.height):
            for x in range(icon.width):
                r, g, b, a = pixels[x, y]
                if key != "homeReference:avatar" and 20 < r < 200 and 20 < g < 210 and abs(r-g) < 45 and g-b > 8 and r-b > 6:
                    pixels[x, y] = (r, g, b, 0)
        x, y = index % 3 * 256, index // 3 * 256
        sheet.alpha_composite(icon, (x, y))
        art["sprites"][key] = {"page": page, "rect": [x, y, icon.width, icon.height],
                               "offset": [0, 0], "size": [icon.width, icon.height]}
    result_source = root / "art_source/defense/result_reference.png"
    with Image.open(result_source) as image:
        result_reference = image.convert("RGBA")
        crystal = result_reference.crop(RESULT_CRYSTAL)
        equipment = result_reference.crop(RESULT_EQUIPMENT)
    pixels = crystal.load()
    for y in range(crystal.height):
        for x in range(crystal.width):
            r, g, b, a = pixels[x, y]
            if max(r, g, b) - min(r, g, b) < 14 and min(r, g, b) > 30:
                pixels[x, y] = (r, g, b, 0)
    sheet.alpha_composite(crystal, (256, 512))
    art["sprites"]["resultReference:crystal"] = {"page": page, "rect": [256, 512, crystal.width, crystal.height],
                                                "offset": [19, 16], "size": [100, 100]}
    sheet.alpha_composite(equipment, (512, 512))
    art["sprites"]["resultReference:equipment"] = {"page": page, "rect": [512, 512, equipment.width, equipment.height],
                                                  "offset": [0, 0], "size": [equipment.width, equipment.height]}
    metadata = PngImagePlugin.PngInfo()
    metadata.add_text("impeccable:prompt", "Sourced from user supplied Image 2, preserved at art_source/defense/home_reference.png; SHA256 " + hashlib.sha256(source.read_bytes()).hexdigest() + "; named crops " + str(ICONS) + "; olive background masked on six icons, avatar retained. Result crystal and equipment sourced from user supplied result screenshot at art_source/defense/result_reference.png; SHA256 " + hashlib.sha256(result_source.read_bytes()).hexdigest() + "; crystal crop " + str(RESULT_CRYSTAL) + "; neutral gray background masked, original cell-relative margin retained. Equipment crop " + str(RESULT_EQUIPMENT) + "; complete item frame retained, no count copied. No AI generation.")
    sheet.save(root / PAGE[6:], pnginfo=metadata)
    provenance_path = root / "art_source/defense/provenance.json"
    if provenance_path.is_file():
        provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
        provenance["runtime_sha256"][PAGE[6:]] = hashlib.sha256((root / PAGE[6:]).read_bytes()).hexdigest()
        provenance_path.write_text(json.dumps(provenance, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    art_path = ROOT / "data/source/defense/art.json"
    art = json.loads(art_path.read_text(encoding="utf-8"))
    register_icons(art)
    art_path.write_text(json.dumps(art, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8", newline="\n")
