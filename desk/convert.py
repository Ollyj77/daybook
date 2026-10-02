#!/usr/bin/env python3
"""Daybook desk: turn a browser screenshot into the 1-bit frame the e-ink panel will show.

Only replaces the frame when the content actually changed, so the panel won't flash for nothing.
Usage: convert.py RAW.png OUTDIR
"""
import hashlib, shutil, sys, time
from pathlib import Path
from PIL import Image

W, H = 800, 480
THRESHOLD = 150          # grey above this becomes white

raw, out = Path(sys.argv[1]), Path(sys.argv[2])
stamp = time.strftime("%Y-%m-%d %H:%M:%S")

img = Image.open(raw).convert("L")
if img.size != (W, H):
    img = img.crop((0, 0, W, H))
bw = img.point(lambda v: 255 if v > THRESHOLD else 0, "1")

# A real desk frame starts with a solid black header bar. Loading or error pages don't,
# so they never replace the last good frame.
header = bw.crop((0, 4, W, 44))
black = header.convert("L").histogram()[0] / (W * 40)
bw.save(out / "last-attempt.png")
if black < 0.6:
    print(f"{stamp} skipped: page wasn't ready (no header). See last-attempt.png")
    sys.exit(0)

frame = out / "frame.png"
new_hash = hashlib.sha256(bw.tobytes()).hexdigest()
old_hash = hashlib.sha256(Image.open(frame).convert("1").tobytes()).hexdigest() if frame.exists() else ""
if new_hash == old_hash:
    print(f"{stamp} unchanged")
    sys.exit(0)

tmp = out / "frame.tmp.png"
bw.save(tmp)
shutil.move(tmp, frame)
(out / "updated.txt").write_text(stamp)
print(f"{stamp} updated")

# Once the e-paper panel is connected, this is where the frame gets sent to it.
display = Path(__file__).with_name("display.py")
if display.exists():
    import subprocess
    subprocess.run([sys.executable, str(display), str(frame)], check=False)
