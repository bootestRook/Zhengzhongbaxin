"""Preserve an Android screenshot and make a small inspection copy."""
from pathlib import Path
import subprocess
import sys
from PIL import Image

out = Path(__file__).resolve().parent
path = out / (sys.argv[1] + ".png")
path.write_bytes(subprocess.check_output([r"D:\leidian\LDPlayer9\adb.exe", "-s", "emulator-5554", "exec-out", "screencap", "-p"]))
preview = Image.open(path)
preview.thumbnail((640, 1138))
preview.save(path.with_name(path.stem + "_preview.png"))
