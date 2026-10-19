"""Run the existing native acceptance driver against source or a clean EXE/PCK."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT))
from tools.project import find_godot

mode = sys.argv[1]
output = HERE / (mode + "_acceptance")
output.mkdir(exist_ok=True)
expectations = json.loads((ROOT / "validation/exe_package_20261015/expectations.json").read_text(encoding="utf-8"))
for entry in expectations["raw_files"]:
    entry["sha256"] = hashlib.sha256((ROOT / entry["path"].removeprefix("res://")).read_bytes()).hexdigest()
expected_path = HERE / "expectations.json"
expected_path.write_text(json.dumps(expectations, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
with tempfile.TemporaryDirectory(prefix="t8-melee-native-") as folder:
    clean = Path(folder)
    if mode == "source":
        command = [find_godot(), "--path", str(ROOT)]
        cwd = ROOT
    else:
        for name in ["defense-demo.exe", "defense-demo.pck"]:
            shutil.copy2(ROOT / "build/windows" / name, clean / name)
        command = [find_godot(), "--main-pack", str(clean / "defense-demo.pck")]
        cwd = clean
    command += ["--fixed-fps", "60", "--resolution", "480x960", "--audio-driver", "Dummy",
                "--script", str(ROOT / "validation/exe_package_20261015/capture.gd"),
                "--", output.as_posix(), expected_path.as_posix()]
    with (HERE / (mode + "_acceptance.log")).open("wb") as log:
        result = subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT, timeout=300,
                                creationflags=subprocess.CREATE_NO_WINDOW)
    text = (HERE / (mode + "_acceptance.log")).read_text(encoding="utf-8")
    assert result.returncode == 0 and "SCRIPT ERROR:" not in text and "ERROR:" not in text, text[-4000:]
    report = json.loads((output / "report.json").read_text(encoding="utf-8"))
    assert not report["errors"], report
    print(json.dumps({"mode": mode, "assets": report["assets_loaded"], "missing_glyphs": report["missing_glyphs"],
                      "captures": len(report["captures"]), "battle": report["battle"]}, ensure_ascii=False))
    if mode != "source":
        from PIL import Image, ImageChops
        comparisons = []
        for original in sorted((HERE / "source_acceptance").glob("*.png")):
            final = output / original.name
            a, b = Image.open(original).convert("RGB"), Image.open(final).convert("RGB")
            comparisons.append({"name": original.name, "identical": a.size == b.size and ImageChops.difference(a, b).getbbox() is None})
        (HERE / "source_vs_exe.json").write_text(json.dumps(comparisons, indent=2) + "\n", encoding="utf-8", newline="\n")
        print("Pixel parity:", sum(x["identical"] for x in comparisons), "/", len(comparisons))
        assert all(x["identical"] for x in comparisons), comparisons
