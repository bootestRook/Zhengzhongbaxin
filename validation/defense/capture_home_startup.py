"""Capture the actual main-scene boot through 启动游戏.cmd.

A temporary, nonvisual recorder node captures the real viewport, then quits.
The exact inserted blocks are removed even on failure; no gameplay is replaced.
"""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
scene_path = ROOT / "scenes/main.tscn"
capture = ROOT / "validation/defense/home_normal_startup_720.png"
ext = '[ext_resource type="Script" path="res://validation/defense/home_startup_probe.gd" id="home_startup_probe"]\n\n'
node = '\n[node name="HomeStartupProbe" type="Node" parent="."]\nscript = ExtResource("home_startup_probe")\n'
scene = scene_path.read_text(encoding="utf-8")
assert 'id="home_startup_probe"' not in scene
if capture.exists():
    capture.unlink()
at = scene.index("[sub_resource")
scene_path.write_text(scene[:at] + ext + scene[at:] + node, encoding="utf-8", newline="\n")
try:
    proc = subprocess.Popen(["cmd.exe", "/d", "/c", "启动游戏.cmd"], cwd=ROOT,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            creationflags=subprocess.CREATE_NO_WINDOW)
    try:
        output, _ = proc.communicate(timeout=45)
    except subprocess.TimeoutExpired:
        proc.terminate()
        raise
    (ROOT / "validation/defense/home_normal_startup.log").write_bytes(output)
    if proc.returncode != 0 or not capture.exists() or b"ERROR:" in output:
        raise RuntimeError(output.decode("utf-8", errors="replace"))
    print("[OK] normal launcher/main-scene capture: " + str(capture))
finally:
    current = scene_path.read_text(encoding="utf-8")
    scene_path.write_text(current.replace(ext, "", 1).replace(node, "", 1),
                          encoding="utf-8", newline="\n")
