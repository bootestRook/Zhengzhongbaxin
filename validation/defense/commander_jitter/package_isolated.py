"""Build the current snapshot without competing with the open editor's cache."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT))
from tools import release_manifest

stage = Path(tempfile.mkdtemp(prefix="t8-melee-package-"))
(HERE / "package_stage.json").write_text(
    json.dumps({"stage": str(stage)}, indent=2) + "\n", encoding="utf-8", newline="\n"
)
for item in ROOT.iterdir():
    if item.name in {".godot", ".import", "build", "validation", ".impeccable"}:
        continue
    target = stage / item.name
    if item.is_dir():
        shutil.copytree(item, target, ignore=shutil.ignore_patterns("__pycache__"))
    else:
        shutil.copy2(item, target)
# Preserve the documentation's local evidence links without copying recordings.
pending = list(stage.rglob("*.md"))
while pending:
    document = pending.pop()
    for raw in re.findall(r"(?<!!)\[[^\]]+\]\(([^)]+)\)", document.read_text(encoding="utf-8")):
        value = raw.strip().strip("<>").split("#", 1)[0]
        if not value or "://" in value or value.startswith("mailto:"):
            continue
        target = (document.parent / value).resolve()
        if not target.is_relative_to(stage) or target.exists():
            continue
        source_file = ROOT / target.relative_to(stage)
        assert source_file.is_file(), source_file
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_file, target)
        if target.suffix == ".md":
            pending.append(target)
print("Isolated snapshot:", stage, flush=True)
with (HERE / "isolated_export.log").open("wb") as log:
    result = subprocess.run(
        [sys.executable, "-u", "-X", "utf8", "tools/package.py", "export", "exe"],
        cwd=stage, stdout=log, stderr=subprocess.STDOUT,
    )
if result.returncode:
    print((HERE / "isolated_export.log").read_text(encoding="utf-8")[-4000:])
    raise SystemExit(result.returncode)
manifest = json.loads((stage / "build/windows/package-manifest.json").read_text(encoding="utf-8"))
source = release_manifest.build_manifest()
print("Source fingerprint:", source["combined_sha256"], flush=True)
print("Build fingerprint:", manifest["source_combined_sha256"], flush=True)
assert source["combined_sha256"] == manifest["source_combined_sha256"], "source changed or import metadata differs"
destination = ROOT / "build/windows"
assert destination.resolve().is_relative_to(ROOT.resolve())
destination.mkdir(exist_ok=True, parents=True)
for item in manifest["files"]:
    shutil.copy2(stage / "build/windows" / item["path"], destination / item["path"])
shutil.copy2(stage / "build/windows/package-manifest.json", destination / "package-manifest.json")
print("Updated:", destination, flush=True)
