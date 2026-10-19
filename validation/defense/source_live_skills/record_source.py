"""Record the running source game through ADB without changing its process or data."""
import argparse
import datetime
import hashlib
import json
import subprocess
import time
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("name")
p.add_argument("--seconds", type=int, default=60)
p.add_argument("--tap", type=int, nargs=2, metavar=("X", "Y"))
a = p.parse_args()
out = Path(__file__).resolve().parent
adb = [r"D:\leidian\LDPlayer9\adb.exe", "-s", "emulator-5554"]
remote = "/sdcard/codex_source_skills_20261014_" + a.name + ".mp4"
start = datetime.datetime.now(datetime.timezone.utc).isoformat()
r = subprocess.Popen(adb + ["shell", "screenrecord", "--size", "720x1280", "--bit-rate", "12000000", "--time-limit", str(a.seconds), remote], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8")
if a.tap:
    if not (0 <= a.tap[0] < 1440 and 0 <= a.tap[1] < 2560):
        r.terminate()
        raise ValueError("tap outside observed portrait device bounds")
    time.sleep(0.5)
    subprocess.run(adb + ["shell", "input", "tap", *map(str, a.tap)], check=True, capture_output=True)
_, error = r.communicate()
if r.returncode:
    raise RuntimeError(error)
path = out / (a.name + ".mp4")
subprocess.run(adb + ["pull", remote, str(path)], check=True, capture_output=True)
probe = subprocess.run(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)], check=True, capture_output=True, text=True, encoding="utf-8")
meta = {"capture": "ADB Android screenrecord MP4; no process injection or game-file changes", "start_utc": start,
        "end_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "tap": a.tap, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "probe": json.loads(probe.stdout)}
path.with_suffix(".json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
print("[RECORDED]", path, flush=True)
