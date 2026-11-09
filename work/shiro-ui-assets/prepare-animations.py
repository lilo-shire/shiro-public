"""Pack Shiro's supplied transparent PNG frames without changing their timing.

Usage: python prepare-animations.py /path/to/кадры-192
Requires Pillow. Runtime apps use only the resulting PNG atlases and manifest.
"""
from pathlib import Path
import hashlib
import json
import sys
from PIL import Image

root = Path(__file__).resolve().parent
source = Path(sys.argv[1])
target = root / "animations"
target.mkdir(exist_ok=True)
clips = {}
names = {0: ("ожидание", "idle", True), 3: ("взмах", "wave", False),
         5: ("испуг", "fear", False), 7: ("они", "focus", True),
         8: ("очки", "glasses", False)}
for row, (name, stem, loop) in names.items():
    files = sorted((source / name).glob("f_*.png"))
    if not files:
        raise ValueError("Missing frames: " + name)
    atlas = Image.new("RGBA", (1920, 208 * ((len(files) + 9) // 10)))
    for index, path in enumerate(files):
        if path.name != f"f_{index:03d}.png":
            raise ValueError("Non-contiguous frames: " + str(path))
        with Image.open(path) as original:
            frame = original.convert("RGBA")
            if frame.size != (192, 208):
                raise ValueError("Wrong frame dimensions: " + str(path))
            # Paste RGBA as-is: using it as its own mask would multiply alpha.
            atlas.paste(frame, (index % 10 * 192, index // 10 * 208))
    filename = stem + ".png"
    atlas.save(target / filename, optimize=True)
    # All supplied GIFs and matching frame sets are 25 fps (40 ms/frame).
    clips[str(row)] = dict(file=filename, frames=len(files), fps=25, loop=loop,
                          sha256=hashlib.sha256((target / filename).read_bytes()).hexdigest())
    print(name, len(files), "frames,", len(files) / 25, "seconds")
(target / "manifest.json").write_text(json.dumps(dict(version=1, width=192, height=208,
    columns=10, clips=clips), indent=2) + "\n")
(target / "README.md").write_text("""# Анимации Широ

Прозрачные PNG-атласы из новых анимаций, 25 кадров в секунду.
Размер кадра — 192 × 208, в атласе по 10 кадров в строке.

- idle.png — ожидание, 150 кадров / 6 секунд, повторяется.
- wave.png — взмах, 100 кадров / 4 секунды, один раз.
- fear.png — испуг, 100 кадров / 4 секунды, один раз.
- focus.png — они, 100 кадров / 4 секунды, повторяется.
- glasses.png — очки, 150 кадров / 6 секунд, один раз.

Порядок кадров идёт слева направо, затем сверху вниз.
manifest.json задаёт файлы, длительность и режим повтора для обоих приложений.
""")
